enum ScreenWidthClass {
  smallPhone,
  standardPhone,
  largePhone,
  tabletPortrait,
  tabletLandscape,
}

ScreenWidthClass classifyScreenWidth(double width) {
  if (width < 375) {
    return ScreenWidthClass.smallPhone;
  }
  if (width < 428) {
    return ScreenWidthClass.standardPhone;
  }
  if (width < 768) {
    return ScreenWidthClass.largePhone;
  }
  if (width < 1024) {
    return ScreenWidthClass.tabletPortrait;
  }
  return ScreenWidthClass.tabletLandscape;
}

extension ScreenWidthClassX on ScreenWidthClass {
  bool get isTablet {
    return this == ScreenWidthClass.tabletPortrait ||
        this == ScreenWidthClass.tabletLandscape;
  }

  bool get isSmallPhone {
    return this == ScreenWidthClass.smallPhone;
  }
}
