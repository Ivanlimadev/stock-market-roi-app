import 'package:flutter/material.dart';
import '../theme/app_theme_colors.dart';

/// Placeholder de carregamento (shimmer skeleton).
///
/// Uso típico:
/// ```dart
/// stocks.when(
///   loading: () => const StockListSkeleton(),
///   ...
/// )
/// ```
///
/// Composição: blocos cinza ([Skeleton]) envoltos por [ShimmerLoading], que
/// passa um brilho animado por cima de toda a sub-árvore com um único
/// `AnimationController` (leve mesmo com vários blocos).

/// Um bloco cinza arredondado. Sozinho é estático; ganha o shimmer quando
/// está dentro de um [ShimmerLoading].
class Skeleton extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  const Skeleton({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 6,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        shape: shape,
        borderRadius:
            shape == BoxShape.rectangle ? BorderRadius.circular(radius) : null,
      ),
    );
  }
}

/// Passa um brilho horizontal animado por cima do [child] (geralmente uma
/// árvore de [Skeleton]). Um controller, repetindo.
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base      = context.colors.surfaceAlt;
    final highlight = context.colors.border;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [base, highlight, base],
            stops: const [0.35, 0.5, 0.65],
            transform: _SlidingGradientTransform(_controller.value),
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  /// 0..1 ao longo do ciclo da animação.
  final double slidePercent;
  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // Mapeia 0..1 para -width..+width, varrendo da esquerda pra direita.
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2 - 1),
      0,
      0,
    );
  }
}

/// Skeleton da lista de ações — espelha o layout de `_StockListTile`
/// (logo 40x40 · símbolo/nome · preço/variação).
class StockListSkeleton extends StatelessWidget {
  final int count;
  const StockListSkeleton({super.key, this.count = 10});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        itemBuilder: (_, _) => const _StockTileSkeleton(),
      ),
    );
  }
}

class _StockTileSkeleton extends StatelessWidget {
  const _StockTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: const [
          Skeleton(width: 40, height: 40, radius: 10),
          SizedBox(width: 8),
          // espaço aproximado do botão "+carteira"
          SizedBox(width: 30),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 56, height: 13),
                SizedBox(height: 6),
                Skeleton(width: 130, height: 11),
              ],
            ),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Skeleton(width: 54, height: 13),
              SizedBox(height: 6),
              Skeleton(width: 46, height: 18, radius: 6),
            ],
          ),
        ],
      ),
    );
  }
}
