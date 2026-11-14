import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_brand_header.dart';
import '../../auth/controller/auth_controller.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _openNext();
  }

  /// The 2.4 second show runs in parallel with Session restore; whatever
  /// finishes last decides when the next screen opens.
  Future<void> _openNext() async {
    await Future.wait([
      Future<void>.delayed(const Duration(milliseconds: 2400)),
      ref
          .read(authControllerProvider.future)
          .then<void>((_) {}, onError: (_, _) {}),
    ]);
    if (!mounted) return;
    final session = ref.read(authControllerProvider).asData?.value.session;
    context.go(session?.user.role?.location ?? '/roles');
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SplashIllustration(),
            const SizedBox(height: 24),
            const AppBrandMark(),
          ],
        ),
      ),
    );
  }
}

class _SplashIllustration extends StatefulWidget {
  const _SplashIllustration();

  @override
  State<_SplashIllustration> createState() => _SplashIllustrationState();
}

class _SplashIllustrationState extends State<_SplashIllustration> {
  static const _width = 223.152;
  static const _height = 207.992;

  late final Future<ui.Image> _maskFuture = _loadMask();
  ui.Image? _maskImage;

  Future<ui.Image> _loadMask() async {
    final picture = await vg.loadPicture(
      const SvgAssetLoader('assets/images/splash_illustration_mask.svg'),
      null,
    );
    try {
      return await picture.picture.toImage(
        picture.size.width.ceil(),
        picture.size.height.ceil(),
      );
    } finally {
      picture.picture.dispose();
    }
  }

  @override
  void dispose() {
    _maskImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image>(
      future: _maskFuture,
      builder: (context, snapshot) {
        final mask = snapshot.data;
        if (snapshot.hasError) {
          return const SizedBox(
            width: _width,
            height: _height,
            child: Center(
              child: Text(
                'Ilustrasi tidak dapat dimuat.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (mask == null) {
          return const SizedBox(width: _width, height: _height);
        }
        _maskImage = mask;

        return Semantics(
          label: 'Ilustrasi Dampingi',
          image: true,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => ui.ImageShader(
              mask,
              TileMode.clamp,
              TileMode.clamp,
              _identityMatrix(),
              filterQuality: ui.FilterQuality.high,
            ),
            child: SizedBox(
              key: const Key('splash-illustration'),
              width: _width,
              height: _height,
              child: Image.asset(
                'assets/images/splash_illustration.png',
                width: _width,
                height: _height,
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
            ),
          ),
        );
      },
    );
  }

  Float64List _identityMatrix() => Float64List.fromList(const [
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
  ]);
}
