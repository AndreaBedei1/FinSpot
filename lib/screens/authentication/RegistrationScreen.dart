import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seawatch/services/AuthServiceGeneral/RegistrationService.dart';
import 'package:seawatch/services/core/api_client.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _cognomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _cognomeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await RegistrationService().register(
        _nomeController.text,
        _cognomeController.text,
        _emailController.text,
        _passwordController.text,
      );
      TextInput.finishAutofillContext();

      if (!mounted) {
        return;
      }

      Navigator.pushReplacementNamed(context, '/main');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore durante la registrazione.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inputFill = isDark ? const Color(0xFF2B313A) : Colors.grey.shade200;
    final inputText = isDark ? Colors.white : const Color(0xFF111827);
    final inputHint = isDark ? Colors.white70 : Colors.grey.shade700;
    final inputLabel = isDark ? Colors.white : const Color(0xFF374151);
    final inputIcon = isDark ? Colors.white70 : Colors.grey.shade700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrazione'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nomeController,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.givenName],
                    style: TextStyle(color: inputText),
                    cursorColor: Colors.orange,
                    decoration: InputDecoration(
                      hintText: 'Nome',
                      labelText: 'Nome',
                      hintStyle: TextStyle(color: inputHint),
                      labelStyle: TextStyle(color: inputLabel),
                      prefixIcon: Icon(Icons.person_outline, color: inputIcon),
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Inserisci il nome';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cognomeController,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.familyName],
                    style: TextStyle(color: inputText),
                    cursorColor: Colors.orange,
                    decoration: InputDecoration(
                      hintText: 'Cognome',
                      labelText: 'Cognome',
                      hintStyle: TextStyle(color: inputHint),
                      labelStyle: TextStyle(color: inputLabel),
                      prefixIcon: Icon(Icons.badge_outlined, color: inputIcon),
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Inserisci il cognome';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [
                      AutofillHints.username,
                      AutofillHints.email
                    ],
                    style: TextStyle(color: inputText),
                    cursorColor: Colors.orange,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      labelText: 'Email',
                      hintStyle: TextStyle(color: inputHint),
                      labelStyle: TextStyle(color: inputLabel),
                      prefixIcon: Icon(Icons.email_outlined, color: inputIcon),
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.isEmpty) {
                        return 'Inserisci email';
                      }
                      if (!trimmed.contains('@')) {
                        return 'Email non valida';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    autocorrect: false,
                    enableSuggestions: false,
                    style: TextStyle(color: inputText),
                    cursorColor: Colors.orange,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      labelText: 'Password',
                      hintStyle: TextStyle(color: inputHint),
                      labelStyle: TextStyle(color: inputLabel),
                      prefixIcon: Icon(Icons.lock_outline, color: inputIcon),
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if ((value ?? '').length < 6) {
                        return 'La password deve avere almeno 6 caratteri';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    autocorrect: false,
                    enableSuggestions: false,
                    style: TextStyle(color: inputText),
                    cursorColor: Colors.orange,
                    decoration: InputDecoration(
                      hintText: 'Conferma password',
                      labelText: 'Conferma Password',
                      hintStyle: TextStyle(color: inputHint),
                      labelStyle: TextStyle(color: inputLabel),
                      prefixIcon:
                          Icon(Icons.lock_reset_outlined, color: inputIcon),
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Le password non coincidono';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _register,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 56),
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Crea nuovo account'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
