import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common.dart';
import '../../models/platform_model.dart';

void changeIdDialog() {
  var newId = "";
  var msg = "";
  var isInProgress = false;
  TextEditingController controller = TextEditingController();
  gFFI.dialogManager.show((setState, close) {
    submit() async {
      debugPrint("onSubmit");
      newId = controller.text.trim();
      setState(() {
        msg = "";
        isInProgress = true;
        bind.mainChangeId(newId: newId);
      });

      var status = await bind.mainGetAsyncStatus();
      while (status == " ") {
        await Future.delayed(const Duration(milliseconds: 100));
        status = await bind.mainGetAsyncStatus();
      }
      if (status.isEmpty) {
        // ok
        close();
        return;
      }
      setState(() {
        isInProgress = false;
        msg = translate(status);
      });
    }

    return CustomAlertDialog(
      title: Text(translate("Change ID")),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(translate("id_change_tip")),
          const SizedBox(
            height: 12.0,
          ),
          TextField(
            decoration: InputDecoration(
                border: const OutlineInputBorder(),
                errorText: msg.isEmpty ? null : translate(msg)),
            inputFormatters: [
              LengthLimitingTextInputFormatter(16),
              // FilteringTextInputFormatter(RegExp(r"[a-zA-z][a-zA-z0-9\_]*"), allow: true)
            ],
            maxLength: 16,
            controller: controller,
            focusNode: FocusNode()..requestFocus(),
          ),
          const SizedBox(
            height: 4.0,
          ),
          Offstage(
              offstage: !isInProgress, child: const LinearProgressIndicator())
        ],
      ),
      actions: [
        TextButton(onPressed: close, child: Text(translate("Cancel"))),
        TextButton(onPressed: submit, child: Text(translate("OK"))),
      ],
      onSubmit: submit,
      onCancel: close,
    );
  });
}

void changeWhiteList({Function()? callback}) async {
  var newWhiteList = (await bind.mainGetOption(key: 'whitelist')).split(',');
  var newWhiteListField = newWhiteList.join('\n');
  var controller = TextEditingController(text: newWhiteListField);
  var msg = "";
  var isInProgress = false;
  gFFI.dialogManager.show((setState, close) {
    return CustomAlertDialog(
      title: Text(translate("IP Whitelisting")),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(translate("whitelist_sep")),
          const SizedBox(
            height: 8.0,
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                    maxLines: null,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      errorText: msg.isEmpty ? null : translate(msg),
                    ),
                    controller: controller,
                    focusNode: FocusNode()..requestFocus()),
              ),
            ],
          ),
          const SizedBox(
            height: 4.0,
          ),
          Offstage(
              offstage: !isInProgress, child: const LinearProgressIndicator())
        ],
      ),
      actions: [
        TextButton(onPressed: close, child: Text(translate("Cancel"))),
        TextButton(
            onPressed: () async {
              await bind.mainSetOption(key: 'whitelist', value: '');
              callback?.call();
              close();
            },
            child: Text(translate("Clear"))),
        TextButton(
            onPressed: () async {
              setState(() {
                msg = "";
                isInProgress = true;
              });
              newWhiteListField = controller.text.trim();
              var newWhiteList = "";
              if (newWhiteListField.isEmpty) {
                // pass
              } else {
                final ips =
                    newWhiteListField.trim().split(RegExp(r"[\s,;\n]+"));
                // test ip
                final ipMatch = RegExp(r"^\d+\.\d+\.\d+\.\d+$");
                for (final ip in ips) {
                  if (!ipMatch.hasMatch(ip)) {
                    msg = "${translate("Invalid IP")} $ip";
                    setState(() {
                      isInProgress = false;
                    });
                    return;
                  }
                }
                newWhiteList = ips.join(',');
              }
              await bind.mainSetOption(key: 'whitelist', value: newWhiteList);
              callback?.call();
              close();
            },
            child: Text(translate("OK"))),
      ],
      onCancel: close,
    );
  });
}
