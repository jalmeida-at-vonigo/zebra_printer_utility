import 'package:flutter/material.dart';

/// Breakpoint definitions
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

/// Layout type based on screen size
enum LayoutType { mobile, tablet, desktop }

/// A responsive layout widget that adapts to different screen sizes
class ResponsiveLayout extends StatelessWidget {
  final Widget? mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    this.mobile,
    this.tablet,
    this.desktop,
  });

  static LayoutType getLayoutType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < Breakpoints.mobile) {
      return LayoutType.mobile;
    } else if (width < Breakpoints.tablet) {
      return LayoutType.tablet;
    } else {
      return LayoutType.desktop;
    }
  }

  static bool isMobile(BuildContext context) {
    return getLayoutType(context) == LayoutType.mobile;
  }

  static bool isTablet(BuildContext context) {
    return getLayoutType(context) == LayoutType.tablet;
  }

  static bool isDesktop(BuildContext context) {
    return getLayoutType(context) == LayoutType.desktop;
  }

  @override
  Widget build(BuildContext context) {
    final layoutType = getLayoutType(context);

    switch (layoutType) {
      case LayoutType.mobile:
        return mobile ?? tablet ?? desktop ?? const SizedBox();
      case LayoutType.tablet:
        return tablet ?? desktop ?? mobile ?? const SizedBox();
      case LayoutType.desktop:
        return desktop ?? tablet ?? mobile ?? const SizedBox();
    }
  }
}

/// A responsive scaffold that adapts navigation based on screen size
class ResponsiveScaffold extends StatefulWidget {
  final String title;
  final List<ResponsiveScreen> screens;
  final int initialIndex;

  const ResponsiveScaffold({
    super.key,
    required this.title,
    required this.screens,
    this.initialIndex = 0,
  });

  @override
  State<ResponsiveScaffold> createState() => _ResponsiveScaffoldState();
}

class _ResponsiveScaffoldState extends State<ResponsiveScaffold> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = !ResponsiveLayout.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          if (isLargeScreen)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              labelType: NavigationRailLabelType.selected,
              destinations: widget.screens.map((screen) {
                return NavigationRailDestination(
                  icon: Icon(screen.icon),
                  selectedIcon: Icon(screen.selectedIcon ?? screen.icon),
                  label: Text(screen.label),
                );
              }).toList(),
            ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: widget.screens[_selectedIndex].builder(context),
          ),
        ],
      ),
      bottomNavigationBar: isLargeScreen
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              destinations: widget.screens.map((screen) {
                return NavigationDestination(
                  icon: Icon(screen.icon),
                  selectedIcon: Icon(screen.selectedIcon ?? screen.icon),
                  label: screen.label,
                );
              }).toList(),
            ),
    );
  }
}

/// A screen definition for responsive navigation
class ResponsiveScreen {
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final WidgetBuilder builder;

  const ResponsiveScreen({
    required this.label,
    required this.icon,
    this.selectedIcon,
    required this.builder,
  });
}

/// A responsive container that adjusts padding based on screen size
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? mobilePadding;
  final EdgeInsetsGeometry? tabletPadding;
  final EdgeInsetsGeometry? desktopPadding;
  final double? maxWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.mobilePadding,
    this.tabletPadding,
    this.desktopPadding,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final layoutType = ResponsiveLayout.getLayoutType(context);
    EdgeInsetsGeometry padding;

    switch (layoutType) {
      case LayoutType.mobile:
        padding = mobilePadding ?? const EdgeInsets.all(16);
        break;
      case LayoutType.tablet:
        padding = tabletPadding ?? const EdgeInsets.all(24);
        break;
      case LayoutType.desktop:
        padding = desktopPadding ?? const EdgeInsets.all(32);
        break;
    }

    return Container(
      alignment: Alignment.topCenter,
      padding: padding,
      child: maxWidth != null
          ? ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth!),
              child: child,
            )
          : child,
    );
  }
}

/// A responsive grid that adjusts column count based on screen size
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double spacing;
  final double runSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final layoutType = ResponsiveLayout.getLayoutType(context);
    int columns;

    switch (layoutType) {
      case LayoutType.mobile:
        columns = mobileColumns;
        break;
      case LayoutType.tablet:
        columns = tabletColumns;
        break;
      case LayoutType.desktop:
        columns = desktopColumns;
        break;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: runSpacing,
        childAspectRatio: 1,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
} 