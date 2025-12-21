import 'package:flutter/material.dart';
import '../services/facebook_auth_service.dart';
import '../utils/app_text_styles.dart';
import 'custom_button.dart';

class FacebookSignInButton extends StatefulWidget {
  final void Function()? onSuccess;
  final String? redirectTo;

  const FacebookSignInButton({super.key, this.onSuccess, this.redirectTo});

  @override
  State<FacebookSignInButton> createState() => _FacebookSignInButtonState();
}

class _FacebookSignInButtonState extends State<FacebookSignInButton> {
  final FacebookAuthService _fbService = FacebookAuthService();

  @override
  void initState() {
    super.initState();
    _fbService.state.addListener(() {
      final s = _fbService.state.value;
      if (!s.isLoading && s.user != null && widget.onSuccess != null) {
        widget.onSuccess!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loading = _fbService.state.value.isLoading;
    final error = _fbService.state.value.errorMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomButton(
          text: 'Continue with Facebook',
          isActive: !loading,
          onPressed: loading
              ? null
              : () async {
                  await _fbService.signInWithFacebook(
                    redirectTo: widget.redirectTo,
                  );
                },
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              error,
              style: AppTextStyles.labelText.copyWith(color: Colors.red),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _fbService.dispose();
    super.dispose();
  }
}
