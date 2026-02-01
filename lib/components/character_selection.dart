import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pixel_adventure/pixel_fighting.dart';

class CharacterSelectionScreen extends Component with HasGameRef<PixelFightingGame>, TapCallbacks, KeyboardHandler {
  final List<String> characters = ['Mask Dude', 'Ninja Frog', 'Pink Man', 'Virtual Guy'];
  String? selectedPlayer1;
  String? selectedPlayer2;
  bool isSelectingPlayer1 = true;
  int _selectedIndex = 0;

  @override
  FutureOr<void> onLoad() async {
    await _setupUI();
    return super.onLoad();
  }

  Future<void> _setupUI() async {
    // Get game size for centering (use fixed resolution if available)
    final gameSize = game.size;
    final centerX = gameSize.x / 2;
    final centerY = gameSize.y / 2;
    
    // If game size is not set, use default
    final screenWidth = gameSize.x > 0 ? gameSize.x : 640.0;
    final screenHeight = gameSize.y > 0 ? gameSize.y : 360.0;
    final screenCenterX = screenWidth / 2;
    final screenCenterY = screenHeight / 2;
    
    // Background overlay (semi-transparent)
    final background = RectangleComponent(
      size: Vector2(screenWidth, screenHeight),
      position: Vector2.zero(),
      paint: Paint()..color = const Color(0xCC000000), // Semi-transparent black
    );
    add(background);
    
    // Selection panel background
    final panelWidth = 600.0;
    final panelHeight = 300.0;
    final panel = RectangleComponent(
      position: Vector2(screenCenterX - panelWidth / 2, screenCenterY - panelHeight / 2),
      size: Vector2(panelWidth, panelHeight),
      paint: Paint()..color = const Color(0xFF211F30),
    );
    add(panel);
    
    // Panel border
    final panelBorder = RectangleComponent(
      position: Vector2(screenCenterX - panelWidth / 2, screenCenterY - panelHeight / 2),
      size: Vector2(panelWidth, panelHeight),
      paint: Paint()
        ..color = const Color(0xFFFFD700)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    add(panelBorder);
    
    // Title with color indicator
    final playerColor = isSelectingPlayer1 ? const Color(0xFF0088FF) : const Color(0xFFFF0000);
    final title = TextComponent(
      text: isSelectingPlayer1 ? 'Player 1: Select Character' : 'Player 2: Select Character',
      position: Vector2(screenCenterX, screenCenterY - 120),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: playerColor,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(title);
    
    // Player indicator badge
    final badge = RectangleComponent(
      position: Vector2(screenCenterX - 280, screenCenterY - 120),
      size: Vector2(80, 30),
      paint: Paint()..color = playerColor,
    );
    add(badge);
    
    final badgeText = TextComponent(
      text: isSelectingPlayer1 ? 'P1' : 'P2',
      position: Vector2(screenCenterX - 280 + 40, screenCenterY - 120 + 15),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(badgeText);

    // Character selection buttons - centered
    final buttonSize = Vector2(120, 140);
    final spacing = 140.0;
    final totalWidth = (characters.length - 1) * spacing;
    final startX = screenCenterX - totalWidth / 2;
    final startY = screenCenterY + 20.0;

    for (int i = 0; i < characters.length; i++) {
      final character = characters[i];
      
      // Check if character is selected by P1 or P2 (from previous selection)
      final isP1Selected = selectedPlayer1 == character;
      final isP2Selected = selectedPlayer2 == character;
      
      // Current selection (keyboard navigation or click) - only for highlighting, not for color
      final isCurrentlySelected = (isSelectingPlayer1 && i == _selectedIndex && selectedPlayer1 == null) ||
          (!isSelectingPlayer1 && i == _selectedIndex && selectedPlayer2 == null);
      
      // isSelected includes both actual selection and current navigation
      final isSelected = isP1Selected || isP2Selected || isCurrentlySelected;
      final isDisabled = (isSelectingPlayer1 && isP2Selected) ||
          (!isSelectingPlayer1 && isP1Selected);
      
      // Determine if this character is selected by P1 or P2 (only if actually selected, not just navigating)
      final isP1Selection = isP1Selected; // Character was actually selected by P1
      final isP2Selection = isP2Selected; // Character was actually selected by P2
      
      final button = CharacterButton(
        character: character,
        position: Vector2(startX + (i * spacing), startY),
        size: buttonSize,
        isSelected: isSelected,
        isDisabled: isDisabled,
        isP1Selection: isP1Selection,
        isP2Selection: isP2Selection,
        onTap: () => _selectCharacter(character),
      );
      add(button);
    }

    // Instructions
    final instructions = TextComponent(
      text: 'Click on a character or use Arrow Keys + Enter',
      position: Vector2(screenCenterX, screenCenterY + 140),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFAAAAAA),
          fontSize: 14,
        ),
      ),
    );
    add(instructions);
  }

  void _selectCharacter(String character) {
    if (isSelectingPlayer1) {
      selectedPlayer1 = character;
      isSelectingPlayer1 = false;
      // Clear and rebuild UI
      removeAll(children);
      _setupUI();
    } else {
      if (character != selectedPlayer1) {
        selectedPlayer2 = character;
        // Start game
        _startGame();
      }
    }
  }

  void _startGame() {
    if (selectedPlayer1 != null && selectedPlayer2 != null) {
      game.startGameWithCharacters(selectedPlayer1!, selectedPlayer2!);
      removeFromParent();
    }
  }
  
  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent) {
      if (keysPressed.contains(LogicalKeyboardKey.arrowLeft) || 
          keysPressed.contains(LogicalKeyboardKey.keyA)) {
        _selectedIndex = (_selectedIndex - 1).clamp(0, characters.length - 1);
        // Rebuild UI to show selection
        removeAll(children);
        _setupUI();
        return true;
      }
      if (keysPressed.contains(LogicalKeyboardKey.arrowRight) || 
          keysPressed.contains(LogicalKeyboardKey.keyD)) {
        _selectedIndex = (_selectedIndex + 1).clamp(0, characters.length - 1);
        // Rebuild UI to show selection
        removeAll(children);
        _setupUI();
        return true;
      }
      if (keysPressed.contains(LogicalKeyboardKey.enter) || 
          keysPressed.contains(LogicalKeyboardKey.space)) {
        // Only select if character is not disabled
        final character = characters[_selectedIndex];
        final isDisabled = (isSelectingPlayer1 && selectedPlayer2 == character) ||
            (!isSelectingPlayer1 && selectedPlayer1 == character);
        if (!isDisabled) {
          _selectCharacter(character);
        }
        return true;
      }
    }
    return false;
  }
}

class CharacterButton extends RectangleComponent with TapCallbacks, HasGameReference {
  final String character;
  final VoidCallback onTap;
  final bool isSelected;
  final bool isDisabled;
  final bool isP1Selection;
  final bool isP2Selection;

  CharacterButton({
    required this.character,
    required this.onTap,
    required this.isSelected,
    required this.isDisabled,
    this.isP1Selection = false,
    this.isP2Selection = false,
    position,
    size,
  }) : super(
          position: position,
          size: size,
          anchor: Anchor.center,
        );

  @override
  FutureOr<void> onLoad() async {
    // Determine selection color (blue for P1, red for P2) - only if actually selected
    Color selectionColor;
    if (isP1Selection) {
      selectionColor = const Color(0xFF0088FF); // Blue for P1
    } else if (isP2Selection) {
      selectionColor = const Color(0xFFFF0000); // Red for P2
    } else if (isSelected) {
      selectionColor = const Color(0xFF00AA00); // Green for current navigation (not yet selected)
    } else {
      selectionColor = const Color(0xFF444444); // Default
    }
    
    // Background - only use player color if actually selected
    paint = Paint()
      ..color = isDisabled
          ? const Color(0xFF333333)
          : (isP1Selection || isP2Selection)
              ? selectionColor.withOpacity(0.3) // Use player color only if selected
              : isSelected
                  ? const Color(0xFF00AA00).withOpacity(0.2) // Light green for navigation
                  : const Color(0xFF444444)
      ..style = PaintingStyle.fill;

    // Character sprite animation (Idle)
    try {
      final idleAnimation = SpriteAnimation.fromFrameData(
        game.images.fromCache('Main Characters/$character/Idle (32x32).png'),
        SpriteAnimationData.sequenced(
          amount: 11,
          stepTime: 0.1,
          textureSize: Vector2.all(32),
        ),
      );
      
      final characterSprite = SpriteAnimationComponent(
        animation: idleAnimation,
        size: Vector2(64, 64),
        position: Vector2(size.x / 2, size.y / 2 - 20),
        anchor: Anchor.center,
      );
      add(characterSprite);
    } catch (e) {
      // Fallback to text if sprite fails to load
      final text = TextComponent(
        text: character.split(' ').first,
        position: Vector2(size.x / 2, size.y / 2 - 20),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            color: isDisabled ? const Color(0xFF888888) : const Color(0xFFFFFFFF),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      add(text);
    }

    // Character name
    final nameText = TextComponent(
      text: character,
      position: Vector2(size.x / 2, size.y - 25),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: isDisabled ? const Color(0xFF888888) : const Color(0xFFFFFFFF),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(nameText);

    // Border with player color - only blue/red if actually selected
    Color borderColor;
    if (isP1Selection) {
      borderColor = const Color(0xFF0088FF); // Blue for P1 (only if selected)
    } else if (isP2Selection) {
      borderColor = const Color(0xFFFF0000); // Red for P2 (only if selected)
    } else if (isSelected) {
      borderColor = const Color(0xFFFFD700); // Gold for current navigation (not yet selected)
    } else if (isDisabled) {
      borderColor = const Color(0xFF666666);
    } else {
      borderColor = const Color(0xFF888888);
    }
    
    final border = RectangleComponent(
      size: size,
      paint: Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 4 : 2,
    );
    add(border);

    // Selection indicator with player color - only show P1/P2 if actually selected
    if (isSelected) {
      Color indicatorColor;
      String indicatorText;
      if (isP1Selection) {
        // Actually selected by P1 - show blue P1
        indicatorColor = const Color(0xFF0088FF); // Blue
        indicatorText = 'P1';
      } else if (isP2Selection) {
        // Actually selected by P2 - show red P2
        indicatorColor = const Color(0xFFFF0000); // Red
        indicatorText = 'P2';
      } else {
        // Just navigating (not yet selected) - show gold checkmark
        indicatorColor = const Color(0xFFFFD700); // Gold
        indicatorText = '✓';
      }
      
      final indicator = TextComponent(
        text: indicatorText,
        position: Vector2(size.x - 15, 15),
        anchor: Anchor.topRight,
        textRenderer: TextPaint(
          style: TextStyle(
            color: indicatorColor,
            fontSize: indicatorText == '✓' ? 24 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      add(indicator);
      
      // Add colored background for P1/P2 indicator - only if actually selected
      if (isP1Selection || isP2Selection) {
        final indicatorBg = RectangleComponent(
          position: Vector2(size.x - 35, 5),
          size: Vector2(30, 20),
          paint: Paint()..color = indicatorColor.withOpacity(0.5),
        );
        add(indicatorBg);
      }
    }

    return super.onLoad();
  }

  @override
  bool onTapDown(TapDownEvent event) {
    if (!isDisabled) {
      onTap();
    }
    return true;
  }
}
