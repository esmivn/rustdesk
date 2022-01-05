use crate::{
    config::{Config, NetworkType},
    tcp::FramedStream,
    udp::FramedSocket,
    ResultType,
};
use anyhow::{bail, Context};
use std::net::SocketAddr;
use tokio::net::ToSocketAddrs;
use tokio_socks::{IntoTargetAddr, TargetAddr};

fn to_socket_addr(host: &str) -> ResultType<SocketAddr> {
    use std::net::ToSocketAddrs;
    let addrs: Vec<SocketAddr> = host.to_socket_addrs()?.collect();
    if addrs.is_empty() {
        bail!("Failed to solve {}", host);
    }
    Ok(addrs[0])
}

pub fn get_target_addr(host: &str) -> ResultType<TargetAddr<'static>> {
    let addr = match Config::get_network_type() {
        NetworkType::Direct => to_socket_addr(&host)?.into_target_addr()?,
        NetworkType::ProxySocks => host.into_target_addr()?,
    }
    .to_owned();
    Ok(addr)
}

pub fn test_if_valid_server(host: &str) -> String {
    let mut host = host.to_owned();
    if !host.contains(":") {
        host = format!("{}:{}", host, 0);
    }

    match Config::get_network_type() {
        NetworkType::Direct => match to_socket_addr(&host) {
            Err(err) => err.to_string(),
            Ok(_) => "".to_owned(),
        },
        NetworkType::ProxySocks => match &host.into_target_addr() {
            Err(err) => err.to_string(),
            Ok(_) => "".to_owned(),
        },
    }
}

pub async fn connect_tcp<'t, T: IntoTargetAddr<'t>>(
    target: T,
    local: SocketAddr,
    ms_timeout: u64,
) -> ResultType<FramedStream> {
    let target_addr = target.into_target_addr()?;

    if let Some(conf) = Config::get_socks() {
        FramedStream::connect(
            conf.proxy.as_str(),
            target_addr,
            local,
            conf.username.as_str(),
            conf.password.as_str(),
            ms_timeout,
        )
        .await
    } else {
        let addrs: Vec<SocketAddr> =
            std::net::ToSocketAddrs::to_socket_addrs(&target_addr)?.collect();
        if addrs.is_empty() {
            bail!("Invalid target addr");
        };

        FramedStream::new(addrs[0], local, ms_timeout)
            .await
            .with_context(|| "Failed to connect to rendezvous server")
    }
}

pub async fn new_udp<T: ToSocketAddrs>(local: T, ms_timeout: u64) -> ResultType<FramedSocket> {
    match Config::get_socks() {
        None => Ok(FramedSocket::new(local).await?),
        Some(conf) => {
            let socket = FramedSocket::new_proxy(
                conf.proxy.as_str(),
                local,
                conf.username.as_str(),
                conf.password.as_str(),
                ms_timeout,
            )
            .await?;
            Ok(socket)
        }
    }
}

pub async fn rebind_udp<T: ToSocketAddrs>(local: T) -> ResultType<Option<FramedSocket>> {
    match Config::get_network_type() {
        NetworkType::Direct => Ok(Some(FramedSocket::new(local).await?)),
        _ => Ok(None),
    }
}