import 'package:flutter/material.dart';

class PermissionHelpDialog extends StatelessWidget {
  const PermissionHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('权限说明'),
      content: const Text(
        '实时推流需要摄像头、麦克风或屏幕录制权限。屏幕共享必须由你点击按钮后在系统选择器中确认，应用不会在后台静默录屏。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
    );
  }
}
