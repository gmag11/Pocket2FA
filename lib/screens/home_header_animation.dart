import 'package:flutter/material.dart';

class HomeHeaderAnimation {
  late final AnimationController _headerController;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _headerSizeFactor;
  late final ScrollController _listScrollController;
  double _lastScrollOffset = 0.0;

  // Getters
  AnimationController get headerController => _headerController;
  Animation<Offset> get headerSlide => _headerSlide;
  Animation<double> get headerSizeFactor => _headerSizeFactor;
  ScrollController get listScrollController => _listScrollController;

  void initialize(TickerProvider vsync) {
    _listScrollController = ScrollController();

    // Slower animation so it's clear the header hides upwards and unfolds downwards
    _headerController = AnimationController(
        vsync: vsync, duration: const Duration(milliseconds: 450));

    _headerSlide =
        Tween<Offset>(begin: const Offset(0, -0.28), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _headerController, curve: Curves.easeInOut));

    _headerSizeFactor =
        CurvedAnimation(parent: _headerController, curve: Curves.easeInOut);

    // Start visible
    _headerController.value = 1.0;

    // Register named listener so we can remove it on dispose
    _listScrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_listScrollController.hasClients) return;
    final offset = _listScrollController.offset;
    final delta = offset - _lastScrollOffset;
    const threshold = 6.0;

    // Only allow hiding when the viewport height is smaller than 4 tiles.
    // AccountTile height is 70 (as defined in account_tile_totp.dart)
    const tileHeight = 70.0;
    final viewport = _listScrollController.position.viewportDimension;
    final allowHide = viewport < (tileHeight * 4);

    if (!allowHide) {
      // If there's enough vertical space, always show the header
      if (_headerController.status != AnimationStatus.forward &&
          _headerController.value < 1.0) {
        _headerController.forward();
      }
    } else {
      if (offset <= 0) {
        // show at top
        if (_headerController.status != AnimationStatus.forward &&
            _headerController.value < 1.0) {
          _headerController.forward();
        }
      } else if (delta > threshold) {
        // scrolling up -> hide (animate upwards)
        if (_headerController.status != AnimationStatus.reverse &&
            _headerController.value > 0.0) {
          _headerController.reverse();
        }
      } else if (delta < -threshold) {
        // scrolling down -> show (unfold downward)
        if (_headerController.status != AnimationStatus.forward &&
            _headerController.value < 1.0) {
          _headerController.forward();
        }
      }
    }

    _lastScrollOffset = offset.clamp(0.0, double.infinity);
  }

  void dispose() {
    _listScrollController.removeListener(_handleScroll);
    _listScrollController.dispose();
    _headerController.dispose();
  }
}
