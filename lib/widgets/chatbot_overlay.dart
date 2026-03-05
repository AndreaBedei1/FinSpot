import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:seawatch/services/chatbot/chatbot_service.dart';
import 'package:seawatch/services/core/api_client.dart';

enum _ChatRole { user, assistant, system }

class _ChatMessage {
  const _ChatMessage({
    required this.role,
    required this.text,
    this.isError = false,
  });

  final _ChatRole role;
  final String text;
  final bool isError;
}

class ChatbotOverlay extends StatefulWidget {
  const ChatbotOverlay({super.key});

  @override
  State<ChatbotOverlay> createState() => _ChatbotOverlayState();
}

class _ChatbotOverlayState extends State<ChatbotOverlay> {
  static const String _offlineMessage =
      'Chatbot non disponibile. Verifica la connessione internet.';

  final ChatbotService _chatbotService = ChatbotService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = <_ChatMessage>[];

  bool _isOpen = false;
  bool _isSending = false;
  bool _isCheckingAvailability = false;
  bool _isChatbotAvailable = true;
  bool _welcomeShown = false;
  String? _conversationId;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleOpen() async {
    final shouldOpen = !_isOpen;
    setState(() {
      _isOpen = shouldOpen;
    });

    if (!shouldOpen) {
      return;
    }

    await _refreshAvailability(showMessageOnFailure: true);
  }

  Future<void> _refreshAvailability({
    bool showMessageOnFailure = false,
  }) async {
    if (_isCheckingAvailability) {
      return;
    }

    setState(() {
      _isCheckingAvailability = true;
    });

    final available = await _chatbotService.isAvailable();
    if (!mounted) {
      return;
    }

    setState(() {
      _isCheckingAvailability = false;
      _isChatbotAvailable = available;
    });

    if (!available) {
      if (showMessageOnFailure) {
        _appendOfflineMessage();
      }
      return;
    }

    if (!_welcomeShown) {
      _welcomeShown = true;
      _appendMessage(
        const _ChatMessage(
          role: _ChatRole.assistant,
          text: "Ciao, sono l'assistente FinSpot. Come posso aiutarti?",
        ),
      );
    }
  }

  void _appendOfflineMessage() {
    if (_messages.isNotEmpty && _messages.last.text == _offlineMessage) {
      return;
    }

    _appendMessage(
      const _ChatMessage(
        role: _ChatRole.system,
        text: _offlineMessage,
        isError: true,
      ),
    );
  }

  void _appendMessage(_ChatMessage message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    if (_isSending) {
      return;
    }

    final text = _textController.text.trim();
    if (text.isEmpty) {
      return;
    }

    _textController.clear();
    _appendMessage(_ChatMessage(role: _ChatRole.user, text: text));

    if (!_isChatbotAvailable) {
      _appendOfflineMessage();
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSending = true;
    });

    try {
      final reply = await _chatbotService.sendMessage(
        message: text,
        conversationId: _conversationId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _conversationId = reply.conversationId ?? _conversationId;
      });
      _appendMessage(
          _ChatMessage(role: _ChatRole.assistant, text: reply.answer));
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      if (_chatbotService.isNetworkError(error)) {
        setState(() {
          _isChatbotAvailable = false;
        });
        _appendOfflineMessage();
      } else {
        _appendMessage(
          _ChatMessage(
            role: _ChatRole.system,
            text: error.message,
            isError: true,
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      _appendMessage(
        const _ChatMessage(
          role: _ChatRole.system,
          text: 'Errore inatteso del chatbot.',
          isError: true,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _resetConversation() async {
    if (_isSending) {
      return;
    }

    if (_isChatbotAvailable) {
      try {
        await _chatbotService.resetConversation(
            conversationId: _conversationId);
      } on ApiException catch (error) {
        if (!mounted) {
          return;
        }
        _appendMessage(
          _ChatMessage(
            role: _ChatRole.system,
            text: error.message,
            isError: true,
          ),
        );
        return;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _conversationId = null;
      _welcomeShown = false;
      _messages.clear();
    });

    if (_isChatbotAvailable) {
      _welcomeShown = true;
      _appendMessage(
        const _ChatMessage(
          role: _ChatRole.assistant,
          text: 'Conversazione azzerata. Inizia pure una nuova domanda.',
        ),
      );
      return;
    }

    _appendOfflineMessage();
  }

  Widget _buildMessageBubble(
    BuildContext context,
    _ChatMessage message,
  ) {
    final theme = Theme.of(context);
    final isUser = message.role == _ChatRole.user;
    final isSystem = message.role == _ChatRole.system;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;

    Color bubbleColor;
    Color textColor;
    if (isUser) {
      bubbleColor = theme.colorScheme.primary;
      textColor = theme.colorScheme.onPrimary;
    } else if (message.isError || isSystem) {
      bubbleColor = const Color(0xFFFDECEC);
      textColor = const Color(0xFFB42318);
    } else {
      bubbleColor = theme.colorScheme.surfaceContainerHighest;
      textColor = theme.colorScheme.onSurface;
    }

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Text(message.text, style: TextStyle(color: textColor)),
          ),
        ),
      ),
    );
  }

  Widget _buildInputRow(BuildContext context) {
    final canSend = _isChatbotAvailable && !_isSending;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: canSend,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: _isChatbotAvailable
                    ? 'Scrivi un messaggio...'
                    : 'Chatbot non disponibile',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: canSend ? _sendMessage : null,
            icon: _isSending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            tooltip: 'Invia',
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(BuildContext context, double width, double height) {
    final theme = Theme.of(context);

    return Material(
      elevation: 12,
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.smart_toy_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Assistente FinSpot',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: _isCheckingAvailability
                        ? null
                        : () =>
                            _refreshAvailability(showMessageOnFailure: true),
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Verifica connessione',
                  ),
                  IconButton(
                    onPressed: _resetConversation,
                    icon: const Icon(Icons.restart_alt),
                    tooltip: 'Nuova chat',
                  ),
                ],
              ),
            ),
            if (_isCheckingAvailability)
              const LinearProgressIndicator(minHeight: 2),
            if (!_isChatbotAvailable)
              Container(
                width: double.infinity,
                color: const Color(0xFFFFF4CE),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: const Text(
                  _offlineMessage,
                  style: TextStyle(
                    color: Color(0xFF8A5B00),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Expanded(
              child: _messages.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Apri la chat e scrivi un messaggio per iniziare.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                      itemCount: _messages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return _buildMessageBubble(context, _messages[index]);
                      },
                    ),
            ),
            _buildInputRow(context),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final safeBottom = media.padding.bottom;
    final safeTop = media.padding.top;
    final isNarrowScreen = media.size.width < 390;
    final isShortScreen = media.size.height < 700;
    final keyboardInset = media.viewInsets.bottom;
    final keyboardOpen = keyboardInset > 0;
    final bottomOffset = safeBottom + 12 + (keyboardOpen ? keyboardInset : 60);
    final panelBottom = bottomOffset + 58;
    final panelTop = safeTop + 8;
    final availablePanelHeight =
        math.max(0.0, media.size.height - panelBottom - panelTop);
    final horizontalInset = isNarrowScreen ? 8.0 : 10.0;
    final maxPanelWidth = isNarrowScreen ? 340.0 : 380.0;
    final panelWidth = math.min(
      maxPanelWidth,
      media.size.width - (horizontalInset * 2),
    );
    final maxPanelHeight = keyboardOpen
        ? (isShortScreen ? 300.0 : 340.0)
        : (isShortScreen ? 380.0 : 470.0);
    final minPanelHeight = keyboardOpen
        ? (isShortScreen ? 160.0 : 190.0)
        : (isShortScreen ? 200.0 : 260.0);
    final heightFactor = keyboardOpen
        ? (isShortScreen ? 0.38 : 0.44)
        : (isShortScreen ? 0.48 : 0.56);
    final desiredPanelHeight = math.min(
      maxPanelHeight,
      math.max(minPanelHeight, media.size.height * heightFactor),
    );
    final panelHeight = math.min(desiredPanelHeight, availablePanelHeight);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: horizontalInset,
          bottom: panelBottom,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.97, end: 1).animate(animation),
                  child: child,
                ),
              );
            },
            child: _isOpen
                ? _buildPanel(context, panelWidth, panelHeight)
                : const SizedBox.shrink(),
          ),
        ),
        Positioned(
          right: 12,
          bottom: bottomOffset,
          child: FloatingActionButton.small(
            heroTag: 'chatbot_toggle_fab',
            onPressed: _toggleOpen,
            tooltip: _isOpen ? 'Chiudi chatbot' : 'Apri chatbot',
            child: Icon(
              _isOpen ? Icons.close : Icons.chat_bubble_outline,
            ),
          ),
        ),
      ],
    );
  }
}
