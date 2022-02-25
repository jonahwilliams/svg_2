import 'dart:math' as math;
import 'dart:typed_data';

import 'package:compiler/src/parser/util.dart';
import 'package:compiler/src/tesspeller.dart';
import 'package:meta/meta.dart';

import 'package:vector_math/vector_math_64.dart';

import 'path.dart';
import 'paint.dart';

@immutable
abstract class DrawCommand {
  const DrawCommand();

  bool canCombine(DrawCommand next);

  DrawCommand combine(DrawCommand other);
}

@immutable
class DrawPathCommand extends DrawCommand {
  DrawPathCommand(this.path, this.paint);
  final Path path;
  final Paint paint;

  @override
  int get hashCode => Object.hash(path, paint);

  @override
  bool operator ==(Object? other) {
    return other is DrawPathCommand &&
        other.path == path &&
        other.paint == paint;
  }

  bool canCombine(DrawCommand next) => false;

  DrawCommand combine(DrawCommand other) {
    throw StateError('Cant combine path commabds');
  }
}

@immutable
class DrawVerticesCommand extends DrawCommand {
  const DrawVerticesCommand(
    this.vertices,
    this.paint,
    this.colors,
    this.indices,
  );

  final Float32List vertices;
  final Int32List? colors;
  final Paint? paint;
  final Uint16List? indices;

  @override
  int get hashCode => Object.hash(Object.hashAll(vertices),
      Object.hashAll(colors ?? []), paint, Object.hashAll(indices ?? []));

  @override
  bool operator ==(Object? other) {
    return other is DrawVerticesCommand &&
        listEquals(vertices, other.vertices) &&
        listEquals(colors, other.colors) &&
        listEquals(indices, other.indices) &&
        other.paint == paint;
  }

  @override
  bool canCombine(DrawCommand next) {
    if (next is DrawVerticesCommand) {
      var leftCanCombine = paint == null || paint?.shader == null;
      var rightCanCombine = next.paint == null || next.paint?.shader == null;
      return leftCanCombine && rightCanCombine;
    }
    return false;
  }

  DrawVerticesCommand combine(DrawCommand other) {
    if (other is! DrawVerticesCommand) {
      throw StateError('message');
    }
    final Int32List newColors =
        Int32List((vertices.length ~/ 2) + (other.vertices.length ~/ 2));
    final Float32List newVertices =
        Float32List.fromList(vertices + other.vertices);
    if (paint != null) {
      for (var i = 0; i < vertices.length ~/ 2; i++) {
        newColors[i] = paint!.color.value;
      }
    } else {
      for (var i = 0; i < vertices.length ~/ 2; i++) {
        newColors[i] = colors![i];
      }
    }

    var offset = (vertices.length ~/ 2);

    if (other.paint != null) {
      for (var i = offset; i < other.vertices.length ~/ 2 + offset; i++) {
        newColors[i] = other.paint!.color.value;
      }
    } else {
      for (var i = offset; i < vertices.length ~/ 2 + offset; i++) {
        newColors[i] = other.colors![i];
      }
    }

    return DrawVerticesCommand(newVertices, null, newColors, null);
  }
}

/// ui.Paint used in masks.
// final ui.Paint _grayscaleDstInPaint = ui.Paint()
//   ..blendMode = ui.BlendMode.dstIn
//   ..colorFilter = const ui.ColorFilter.matrix(<double>[
//     0, 0, 0, 0, 0, //
//     0, 0, 0, 0, 0,
//     0, 0, 0, 0, 0,
//     0.2126, 0.7152, 0.0722, 0, 0,
//   ]); //convert to grayscale (https://www.w3.org/Graphics/Color/sRGB) and use them as transparency

/// Base interface for vector drawing.
@immutable
abstract class Drawable {
  /// A string that should uniquely identify this [Drawable] within its [DrawableRoot].
  String? get id;

  /// Whether this [Drawable] would be visible if [draw]n.
  bool get hasDrawableContent;

  /// Draws the contents or children of this [Drawable] to the `canvas`, using
  /// the `parentPaint` to optionally override the child's paint.
  ///
  /// The `bounds` specify the area to draw in.
  void write(Set<Paint> paints, Set<Path> paths, List<DrawCommand?> commands,
      AffineMatrix currentTransform) {}
}

/// A [Drawable] that can have a [DrawableStyle] applied to it.
@immutable
abstract class DrawableStyleable extends Drawable {
  /// The [DrawableStyle] for this object.
  DrawableStyle? get style;

  /// The 4x4 transform to apply to this [Drawable], if any.
  AffineMatrix? get transform;

  /// Creates an instance with merged style information.
  DrawableStyleable mergeStyle(DrawableStyle newStyle);
}

/// A [Drawable] that can have child [Drawables] and [DrawableStyle].
abstract class DrawableParent implements DrawableStyleable {
  /// The child [Drawables] of this [DrawableParent].
  ///
  /// Each child may itself have children.
  List<Drawable>? get children;

  /// The default color used to provide a potential indirect color value
  /// for the `fill`, `stroke` and `stop-color` of descendant elements.
  ///
  /// See: https://www.w3.org/TR/SVG11/color.html#ColorProperty
  Color? get color;
}

/// Styling information for vector drawing.
///
/// Contains [Paint], [Path], dashing, transform, and text styling information.
@immutable
class DrawableStyle {
  /// Creates a new [DrawableStyle].
  const DrawableStyle({
    this.stroke,
    // this.dashArray,
    // this.dashOffset,
    this.fill,
    // this.textStyle,
    this.pathFillType,
    this.groupOpacity,
    this.clipPath,
    this.mask,
    this.blendMode,
  });

  // /// Used where 'dasharray' is 'none'
  // ///
  // /// This will not result in a drawing operation, but will clear out
  // /// inheritance.
  // static final CircularIntervalList<double> emptyDashArray =
  //     CircularIntervalList<double>(const <double>[]);

  /// If not `null` and not `identical` with [DrawablePaint.empty], will result in a stroke
  /// for the rendered [DrawableShape]. Drawn __after__ the [fill].
  final DrawablePaint? stroke;

  // /// The dashing array to use for the [stroke], if any.
  // final CircularIntervalList<double>? dashArray;

  // /// The [DashOffset] to use for where to begin the [dashArray].
  // final DashOffset? dashOffset;

  /// If not `null` and not `identical` with [DrawablePaint.empty], will result in a fill
  /// for the rendered [DrawableShape].  Drawn __before__ the [stroke].
  final DrawablePaint? fill;

  // /// The style to apply to text elements of this drawable or its chidlren.
  // final DrawableTextStyle? textStyle;

  /// The fill rule to use for this path.
  final PathFillType? pathFillType;

  /// The clip to apply, if any.
  final List<Path>? clipPath;

  /// The mask to apply, if any.
  final DrawableStyleable? mask;

  /// Controls group level opacity. Will be [BlendMode.dstIn] blended with any
  /// children.
  final double? groupOpacity;

  /// The blend mode to apply, if any.
  ///
  /// Setting this will result in at least one [Canvas.saveLayer] call.
  final BlendMode? blendMode;

  /// Creates a new [DrawableStyle] if `parent` is not null, filling in any null
  /// properties on this with the properties from other (except [groupOpacity],
  /// is not inherited).
  static DrawableStyle mergeAndBlend(
    DrawableStyle? parent, {
    DrawablePaint? fill,
    DrawablePaint? stroke,
    // CircularIntervalList<double>? dashArray,
    // DashOffset? dashOffset,
    // DrawableTextStyle? textStyle,
    PathFillType? pathFillType,
    double? groupOpacity,
    List<Path>? clipPath,
    DrawableStyleable? mask,
    BlendMode? blendMode,
  }) {
    return DrawableStyle(
      fill: DrawablePaint.merge(fill, parent?.fill),
      stroke: DrawablePaint.merge(stroke, parent?.stroke),
      // dashArray: dashArray ?? parent?.dashArray,
      // dashOffset: dashOffset ?? parent?.dashOffset,
      // textStyle: DrawableTextStyle.merge(textStyle, parent?.textStyle),
      pathFillType: pathFillType ?? parent?.pathFillType,
      groupOpacity: groupOpacity,
      // clips don't make sense to inherit - applied to canvas with save/restore
      // that wraps any potential children
      clipPath: clipPath,
      mask: mask,
      blendMode: blendMode,
    );
  }

  @override
  String toString() {
    return 'DrawableStyle{$stroke,$fill,$pathFillType,$groupOpacity,$clipPath,$mask}';
  }
}

/// A wrapper class for Flutter's [Paint] class.
///
/// Provides non-opaque access to painting properties.
@immutable
class DrawablePaint {
  /// Creates a new [DrawablePaint] object.
  const DrawablePaint(
    this.style, {
    this.color,
    this.shader,
    this.blendMode,
    this.strokeCap,
    this.strokeJoin,
    this.strokeMiterLimit,
    this.strokeWidth,
  });

  /// Will merge two DrawablePaints, preferring properties defined in `a` if they're not null.
  ///
  /// If `a` is `identical` with [DrawablePaint.empty], `b` will be ignored.
  static DrawablePaint? merge(DrawablePaint? a, DrawablePaint? b) {
    if (a == null && b == null) {
      return null;
    }

    if (b == null && a != null) {
      return a;
    }

    if (identical(a, DrawablePaint.empty) ||
        identical(b, DrawablePaint.empty)) {
      return a ?? b;
    }

    if (a == null) {
      return b;
    }

    // If we got here, the styles should not be null.
    assert(a.style == b!.style,
        'Cannot merge Paints with different PaintStyles; got:\na: $a\nb: $b.');

    return DrawablePaint(
      a.style ?? b!.style,
      color: a.color ?? b!.color,
      shader: a.shader ?? b!.shader,
      blendMode: a.blendMode ?? b!.blendMode,
      strokeCap: a.strokeCap ?? b!.strokeCap,
      strokeJoin: a.strokeJoin ?? b!.strokeJoin,
      strokeMiterLimit: a.strokeMiterLimit ?? b!.strokeMiterLimit,
      strokeWidth: a.strokeWidth ?? b!.strokeWidth,
    );
  }

  /// An empty [DrawablePaint].
  ///
  /// Used to assist with inheritance of painting properties.
  static const DrawablePaint empty = DrawablePaint(null);

  /// Returns whether this paint is null or equivalent to SVG's "none".
  static bool isEmpty(DrawablePaint? paint) {
    return paint == null || paint == empty;
  }

  /// The color to use for this paint when stroking or filling a shape.
  final Color? color;

  /// The [Shader] to use  when stroking or filling a shape.
  final Shader? shader;

  /// The [BlendMode] to use when stroking or filling a shape.
  final BlendMode? blendMode;

  /// Whehter to fill or stroke when drawing this shape.
  final PaintingStyle? style;

  /// The [StrokeCap] for this shape.
  final StrokeCap? strokeCap;

  /// The [StrokeJoin] for this shape.
  final StrokeJoin? strokeJoin;

  /// The stroke miter limit.  See [Paint.strokeMiterLimit].
  final double? strokeMiterLimit;

  /// The width of strokes for this paint.
  final double? strokeWidth;

  Paint toPaint() {
    return Paint(
      blendMode: blendMode,
      color: color,
      shader: shader,
      strokeCap: strokeCap,
      strokeJoin: strokeJoin,
      strokeMiterLimit: strokeMiterLimit,
      strokeWidth: strokeWidth,
      style: style,
    );
  }

  @override
  String toString() {
    if (identical(this, DrawablePaint.empty)) {
      return 'DrawablePaint{}';
    }
    return 'DrawablePaint{$style, color: $color, shader: $shader, blendMode: $blendMode, '
        'strokeCap: $strokeCap, strokeJoin: $strokeJoin, '
        'strokeMiterLimit: $strokeMiterLimit, strokeWidth: $strokeWidth}';
  }
}

// /// A wrapper class for Flutter's [TextStyle] class.
// ///
// /// Provides non-opaque access to text styling properties.
// @immutable
// class DrawableTextStyle {
//   /// Creates a new [DrawableTextStyle].
//   const DrawableTextStyle({
//     this.decoration,
//     this.decorationColor,
//     this.decorationStyle,
//     this.fontWeight,
//     this.fontFamily,
//     this.fontSize,
//     this.fontStyle,
//     this.foreground,
//     this.background,
//     this.letterSpacing,
//     this.wordSpacing,
//     this.height,
//     this.locale,
//     this.textBaseline,
//     this.anchor,
//   });

//   /// Merges two drawable text styles together, prefering set properties from [b].
//   static DrawableTextStyle? merge(DrawableTextStyle? a, DrawableTextStyle? b) {
//     if (b == null) {
//       return a;
//     }
//     if (a == null) {
//       return b;
//     }
//     return DrawableTextStyle(
//       decoration: a.decoration ?? b.decoration,
//       decorationColor: a.decorationColor ?? b.decorationColor,
//       decorationStyle: a.decorationStyle ?? b.decorationStyle,
//       fontWeight: a.fontWeight ?? b.fontWeight,
//       fontStyle: a.fontStyle ?? b.fontStyle,
//       textBaseline: a.textBaseline ?? b.textBaseline,
//       fontFamily: a.fontFamily ?? b.fontFamily,
//       fontSize: a.fontSize ?? b.fontSize,
//       letterSpacing: a.letterSpacing ?? b.letterSpacing,
//       wordSpacing: a.wordSpacing ?? b.wordSpacing,
//       height: a.height ?? b.height,
//       locale: a.locale ?? b.locale,
//       background: a.background ?? b.background,
//       foreground: a.foreground ?? b.foreground,
//       anchor: a.anchor ?? b.anchor,
//     );
//   }

//   /// The [TextDecoration] to draw with this text.
//   final ui.TextDecoration? decoration;

//   /// The color to use when drawing the decoration.
//   final Color? decorationColor;

//   /// The [TextDecorationStyle] of the decoration.
//   final ui.TextDecorationStyle? decorationStyle;

//   /// The weight of the font.
//   final ui.FontWeight? fontWeight;

//   /// The style of the font.
//   final ui.FontStyle? fontStyle;

//   /// The [TextBaseline] to use when drawing this text.
//   final ui.TextBaseline? textBaseline;

//   /// The font family to use when drawing this text.
//   final String? fontFamily;

//   /// The font size to use when drawing this text.
//   final double? fontSize;

//   /// The letter spacing to use when drawing this text.
//   final double? letterSpacing;

//   /// The word spacing to use when drawing this text.
//   final double? wordSpacing;

//   /// The height of the text.
//   final double? height;

//   /// The [Locale] to use when drawing this text.
//   final ui.Locale? locale;

//   /// The background to use when drawing this text.
//   final DrawablePaint? background;

//   /// The foreground to use when drawing this text.
//   final DrawablePaint? foreground;

//   /// The [DrawableTextAnchorPosition] to use when drawing this text.
//   final DrawableTextAnchorPosition? anchor;

//   /// Creates a Flutter [TextStyle], overriding the foreground if specified.
//   // ui.TextStyle toFlutterTextStyle({DrawablePaint? foregroundOverride}) {
//   //   return ui.TextStyle(
//   //     decoration: decoration,
//   //     decorationColor: decorationColor,
//   //     decorationStyle: decorationStyle,
//   //     fontWeight: fontWeight,
//   //     fontStyle: fontStyle,
//   //     textBaseline: textBaseline,
//   //     fontFamily: fontFamily,
//   //     fontSize: fontSize,
//   //     letterSpacing: letterSpacing,
//   //     wordSpacing: wordSpacing,
//   //     height: height,
//   //     locale: locale,
//   //     background: background?.toFlutterPaint(),
//   //     foreground:
//   //         foregroundOverride?.toFlutterPaint() ?? foreground?.toFlutterPaint(),
//   //   );
//   // }

//   @override
//   String toString() =>
//       'DrawableTextStyle{$decoration,$decorationColor,$decorationStyle,$fontWeight,'
//       '$fontFamily,$fontSize,$fontStyle,$foreground,$background,$letterSpacing,$wordSpacing,$height,'
//       '$locale,$textBaseline,$anchor}';
// }

/// How to anchor text.
enum DrawableTextAnchorPosition {
  /// The offset specifies the start of the text.
  start,

  /// The offset specifies the midpoint of the text.
  middle,

  /// The offset specifies the end of the text.
  end,
}

// /// A [Drawable] for text objects.
// class DrawableText implements Drawable {
//   /// Creates a new [DrawableText] object.
//   ///
//   /// One of fill or stroke must be specified.
//   DrawableText(
//     this.id,
//     this.fill,
//     this.stroke,
//     this.offset,
//     this.anchor, {
//     this.transform,
//   }) : assert(fill != null || stroke != null);

//   @override
//   final String? id;

//   /// The offset for positioning the text. The [anchor] property controls
//   /// how this offset is interpreted.
//   final Point offset;

//   /// The anchor for the offset, i.e. whether it is the start, middle, or end
//   /// of the text.
//   final DrawableTextAnchorPosition anchor;

//   /// If specified, how to draw the interior portion of the text.
//   final ui.Paragraph? fill;

//   /// If specified, how to draw the outline of the text.
//   final ui.Paragraph? stroke;

//   /// A transform to apply when drawing the text.
//   final AffineMatrix? transform;

//   @override
//   bool get hasDrawableContent =>
//       (fill?.width ?? 0.0) + (stroke?.width ?? 0.0) > 0.0;

//   @override
//   void write() {
//     dynamic canvas;
//     if (!hasDrawableContent) {
//       return;
//     }
//     if (transform != null) {
//       canvas.save();
//       canvas.transform(transform!);
//     }
//     if (fill != null) {
//       canvas.drawParagraph(fill!, resolveOffset(fill!, anchor, offset));
//     }
//     if (stroke != null) {
//       canvas.drawParagraph(stroke!, resolveOffset(stroke!, anchor, offset));
//     }
//     if (transform != null) {
//       canvas.restore();
//     }
//   }

//   /// Determines the correct location for an [Offset] given laid-out
//   /// [paragraph] and a [DrawableTextPosition].
//   static Point resolveOffset(
//     ui.Paragraph paragraph,
//     DrawableTextAnchorPosition anchor,
//     Point offset,
//   ) {
//     switch (anchor) {
//       case DrawableTextAnchorPosition.middle:
//         return Point(
//           offset.x - paragraph.longestLine / 2,
//           offset.y - paragraph.alphabeticBaseline,
//         );
//       case DrawableTextAnchorPosition.end:
//         return Point(
//           offset.x - paragraph.longestLine,
//           offset.y - paragraph.alphabeticBaseline,
//         );
//       case DrawableTextAnchorPosition.start:
//         return Point(
//           offset.x,
//           offset.y - paragraph.alphabeticBaseline,
//         );
//       default:
//         return offset;
//     }
//   }
// }

/// Contains reusable drawing elements that can be referenced by a String ID.
class DrawableDefinitionServer {
  final Map<String, DrawableGradient> _gradients = <String, DrawableGradient>{};
  final Map<String, List<Path>> _clipPaths = <String, List<Path>>{};
  final Map<String, DrawableStyleable> _drawables =
      <String, DrawableStyleable>{};

  /// An empty IRI for SVGs.
  static const String emptyUrlIri = 'url(#)';

  /// Attempt to lookup a [Drawable] by [id].
  DrawableStyleable? getDrawable(String id, {bool nullOk = false}) {
    final DrawableStyleable? value = _drawables[id];
    if (value == null && nullOk != true) {
      throw StateError('Expected to find Drawable with id $id.\n'
          'Have ids: ${_drawables.keys}');
    }
    return value;
  }

  /// Add a [Drawable] that can later be referred to by [id].
  void addDrawable(String id, DrawableStyleable drawable) {
    _drawables[id] = drawable;
  }

  /// Attempt to lookup a pre-defined [Shader] by [id].
  ///
  /// [id] and [bounds] must not be null.
  Shader? getShader(String id, Rect bounds) {
    final DrawableGradient? srv = _gradients[id];
    return srv != null ? srv.createShader(bounds) : null;
  }

  /// Retreive a gradient from the pre-defined [DrawableGradient] collection.
  T? getGradient<T extends DrawableGradient?>(String id) {
    return _gradients[id] as T?;
  }

  /// Add a [DrawableGradient] to the pre-defined collection by [id].
  void addGradient(String id, DrawableGradient gradient) {
    _gradients[id] = gradient;
  }

  /// Get a [Set<Path>] of clip paths by [id].
  List<Path>? getClipPath(String id) {
    return _clipPaths[id];
  }

  /// Add a [Set<Path>] of clip paths by [id].
  void addClipPath(String id, List<Path> paths) {
    _clipPaths[id] = paths;
  }
}

/// Determines how to transform the points given for a gradient.
enum GradientUnitMode {
  /// The gradient vector(s) are transformed by the space in the object containing the gradient.
  objectBoundingBox,

  /// The gradient vector(s) are taken as is.
  userSpaceOnUse,
}

/// Basic information describing a gradient.
@immutable
abstract class DrawableGradient {
  /// Initializes basic values.
  const DrawableGradient(
    this.offsets,
    this.colors, {
    this.spreadMethod = TileMode.clamp,
    this.unitMode = GradientUnitMode.objectBoundingBox,
    this.transform,
  });

  /// Specifies where `colors[i]` begins in the gradient.
  ///
  /// Number of elements must equal the number of elements in [colors].
  final List<double>? offsets;

  /// The colors to use for the gradient.
  final List<Color>? colors;

  /// The [ui.TileMode] to use for this gradient.
  final TileMode spreadMethod;

  /// The [GradientUnitMode] for any vectors specified by this gradient.
  final GradientUnitMode unitMode;

  /// The transform to apply to this gradient.
  final AffineMatrix? transform;

  /// Creates a [ui.Shader] (i.e. a [ui.Gradient]) from this object.
  Shader createShader(Rect bounds);
}

/// Represents the data needed to create a [Gradient.linear].
@immutable
class DrawableLinearGradient extends DrawableGradient {
  /// Creates a new [DrawableLinearGradient].
  const DrawableLinearGradient({
    required this.from,
    required this.to,
    required List<double> offsets,
    required List<Color> colors,
    required TileMode spreadMethod,
    required GradientUnitMode unitMode,
    AffineMatrix? transform,
  }) : super(
          offsets,
          colors,
          spreadMethod: spreadMethod,
          unitMode: unitMode,
          transform: transform,
        );

  /// The starting offset of this gradient.
  final Point from;

  /// The ending offset of this gradient.
  final Point to;

  @override
  Shader createShader(Rect bounds) {
    final bool isObjectBoundingBox =
        unitMode == GradientUnitMode.objectBoundingBox;

    AffineMatrix m4transform = transform ?? AffineMatrix.identity;

    if (isObjectBoundingBox) {
      final AffineMatrix scale =
          AffineMatrix(bounds.width, 0.0, 0.0, bounds.height, 0.0, 0.0);
      final AffineMatrix translate =
          AffineMatrix(1.0, 0.0, 0.0, 1.0, bounds.left, bounds.top);
      m4transform = translate.multiplied(scale).multiplied(m4transform);
    }

    final Point fromPoint = m4transform.transformPoint(
      Point(
        from.x,
        from.y,
      ),
    );
    final Point toPoint = m4transform.transformPoint(
      Point(
        to.x,
        to.y,
      ),
    );

    return LinearGradient(
      from: fromPoint,
      to: toPoint,
      colors: colors!,
      offsets: offsets,
      tileMode: spreadMethod,
    );
  }
}

/// Represents the information needed to create a [Gradient.radial].
@immutable
class DrawableRadialGradient extends DrawableGradient {
  /// Creates a [DrawableRadialGradient].
  const DrawableRadialGradient({
    required this.center,
    required this.radius,
    required this.focal,
    this.focalRadius = 0.0,
    required List<double> offsets,
    required List<Color> colors,
    required TileMode spreadMethod,
    required GradientUnitMode unitMode,
    AffineMatrix? transform,
  }) : super(
          offsets,
          colors,
          spreadMethod: spreadMethod,
          unitMode: unitMode,
          transform: transform,
        );

  /// The center of the radial gradient.
  final Point center;

  /// The radius of the radial gradient.
  final double? radius;

  /// The focal point, if any, for a two point conical gradient.
  final Point focal;

  /// The radius of the focal point.
  final double focalRadius;

  @override
  Shader createShader(Rect bounds) {
    final bool isObjectBoundingBox =
        unitMode == GradientUnitMode.objectBoundingBox;

    AffineMatrix m4transform = transform ?? AffineMatrix.identity;

    if (isObjectBoundingBox) {
      final AffineMatrix scale =
          AffineMatrix(bounds.width, 0.0, 0.0, bounds.height, 0.0, 0.0);
      final AffineMatrix translate =
          AffineMatrix(1.0, 0.0, 0.0, 1.0, bounds.left, bounds.top);
      m4transform = translate.multiplied(scale).multiplied(m4transform);
    }

    return RadialGradient(
      center: Point(center.x, center.y),
      radius: radius!,
      colors: colors!,
      offsets: offsets,
      tileMode: spreadMethod,
      transform: m4transform,
      focalX: focal.x,
      focalY: focal.y,
    );
  }
}

/// Contains the viewport size and offset for a Drawable.
@immutable
class DrawableViewport {
  /// Creates a new DrawableViewport, which acts as a bounding box for the Drawable
  /// and specifies what offset (if any) the coordinate system needs to be translated by.
  ///
  /// Both `rect` and `offset` must not be null.
  const DrawableViewport(
    this.size,
    this.viewBox, {
    this.viewBoxOffset = Point.zero,
  });

  /// The offset for all drawing commands in this Drawable.
  final Point viewBoxOffset;

  /// A [Rect] representing the viewBox of this DrawableViewport.
  Rect get viewBoxRect => Rect.fromLTRB(0, 0, viewBox.x, viewBox.y);

  /// The viewBox size for the drawable.
  final Point viewBox;

  /// The viewport size of the drawable.
  ///
  /// This may or may not be identical to the
  final Point size;

  /// The width of the viewport rect.
  double get width => size.x;

  /// The height of the viewport rect.
  double get height => size.y;

  @override
  String toString() => 'DrawableViewport{$size, viewBox: $viewBox, '
      'viewBoxOffset: $viewBoxOffset}';
}

/// The root element of a drawable.
class DrawableRoot implements DrawableParent {
  /// Creates a new [DrawableRoot].
  const DrawableRoot(
    this.id,
    this.viewport,
    this.children,
    this.definitions,
    this.style, {
    this.transform,
    this.color,
  });

  /// The expected coordinates used by child paths for drawing.
  final DrawableViewport viewport;

  @override
  final String? id;

  @override
  final AffineMatrix? transform;

  @override
  final Color? color;

  @override
  final List<Drawable> children;

  /// Contains reusable definitions such as gradients and clipPaths.
  final DrawableDefinitionServer definitions;

  /// The [DrawableStyle] for inheritence.
  @override
  final DrawableStyle? style;

  /// Scales the `canvas` so that the drawing units in this [Drawable]
  /// will scale to the `desiredSize`.
  ///
  /// If the `viewBox` dimensions are not 1:1 with `desiredSize`, will scale to
  /// the smaller dimension and translate to center the image along the larger
  /// dimension.
  void scaleCanvasToViewBox(dynamic canvas, Point desiredSize) {
    final Matrix4 transform = Matrix4.identity();
    if (scaleCanvasToViewBox2(
      transform,
      desiredSize,
      Rect.fromLTRB(viewport.viewBoxRect.left, viewport.viewBoxRect.top,
          viewport.viewBoxRect.right, viewport.viewBoxRect.bottom),
      viewport.size,
    )) {
      canvas.transform(transform.storage);
    }
  }

  /// Clips the canvas to a rect corresponding to the `viewBox`.
  void clipCanvasToViewBox(dynamic canvas) {
    canvas.clipRect(viewport.viewBoxRect);
  }

  @override
  bool get hasDrawableContent =>
      children.isNotEmpty == true; // && !viewport.viewBox.isEmpty;

  /// Draws the contents or children of this [Drawable] to the `canvas`, using
  /// the `parentPaint` to optionally override the child's paint.
  ///
  /// The `bounds` is not used.
  @override
  void write(Set<Paint> paints, Set<Path> paths, List<DrawCommand?> commands,
      AffineMatrix currentTransform) {
    if (transform != null) {
      currentTransform = currentTransform.multiplied(transform!);
    }
    dynamic canvas;
    if (!hasDrawableContent) {
      return;
    }

    if (transform != null) {
      canvas.save();
      canvas.transform(transform!);
    }

    if (viewport.viewBoxOffset != Point.zero) {
      canvas.translate(viewport.viewBoxOffset.x, viewport.viewBoxOffset.y);
    }
    for (Drawable child in children) {
      child.write(paints, paths, commands, currentTransform);
    }

    if (transform != null) {
      canvas.restore();
    }
    if (viewport.viewBoxOffset != Point.zero) {
      canvas.restore();
    }
  }

  // /// Creates a [Picture] from this [DrawableRoot].
  // ///
  // /// Be cautious about not clipping to the ViewBox - you will be
  // /// allowing your drawing to take more memory than it otherwise would,
  // /// particularly when it is eventually rasterized.
  // Picture toPicture({
  //   Size? size,
  //   bool clipToViewBox = true,
  //   ColorFilter? colorFilter,
  // }) {
  //   if (viewport.viewBox.width == 0) {
  //     throw StateError('Cannot convert to picture with $viewport');
  //   }

  //   final PictureRecorder recorder = PictureRecorder();
  //   final dynamic canvas = Canvas(recorder, viewport.viewBoxRect);
  //   if (colorFilter != null) {
  //     canvas.saveLayer(null, ui.Paint()..colorFilter = colorFilter);
  //   } else {
  //     canvas.save();
  //   }
  //   if (size != null) {
  //     scaleCanvasToViewBox(canvas, size);
  //   }
  //   if (clipToViewBox == true) {
  //     clipCanvasToViewBox(canvas);
  //   }

  //   draw(canvas, viewport.viewBoxRect);
  //   canvas.restore();
  //   return recorder.endRecording();
  // }

  @override
  DrawableRoot mergeStyle(DrawableStyle newStyle) {
    final DrawableStyle mergedStyle = DrawableStyle.mergeAndBlend(
      style,
      fill: newStyle.fill,
      stroke: newStyle.stroke,
      clipPath: newStyle.clipPath,
      mask: newStyle.mask,
      // dashArray: newStyle.dashArray,
      // dashOffset: newStyle.dashOffset,
      pathFillType: newStyle.pathFillType,
      // textStyle: newStyle.textStyle,
    );

    final List<Drawable> mergedChildren =
        children.map<Drawable>((Drawable child) {
      if (child is DrawableStyleable) {
        return child.mergeStyle(mergedStyle);
      }
      return child;
    }).toList();

    return DrawableRoot(
      id,
      viewport,
      mergedChildren,
      definitions,
      mergedStyle,
      transform: transform,
    );
  }
}

/// Represents a group of drawing elements that may share a common `transform`,
/// `stroke`, or `fill`.
class DrawableGroup implements DrawableStyleable, DrawableParent {
  /// Creates a new DrawableGroup.
  const DrawableGroup(
    this.id,
    this.children,
    this.style, {
    this.transform,
    this.color,
  });

  @override
  final String? id;

  @override
  final List<Drawable>? children;
  @override
  final DrawableStyle? style;
  @override
  final AffineMatrix? transform;
  @override
  final Color? color;

  @override
  bool get hasDrawableContent => children != null && children!.isNotEmpty;

  @override
  void write(Set<Paint> paints, Set<Path> paths, List<DrawCommand?> commands,
      AffineMatrix currentTransform) {
    if (transform != null) {
      currentTransform = currentTransform.multiplied(transform!);
    }
    for (final child in children ?? []) {
      child.write(paints, paths, commands, currentTransform);
    }

    // dynamic canvas;
    // if (!hasDrawableContent) {
    //   return;
    // }

    // final Function innerDraw = () {
    //   if (style!.groupOpacity == 0) {
    //     return;
    //   }
    //   if (transform != null) {
    //     canvas.save();
    //     canvas.transform(transform!);
    //   }

    //   bool needsSaveLayer = style!.mask != null;

    //   final ui.Paint blendingPaint = ui.Paint();
    //   if (style!.groupOpacity != null && style!.groupOpacity != 1.0) {
    //     blendingPaint.color = ui.Color.fromRGBO(0, 0, 0, style!.groupOpacity!);
    //     needsSaveLayer = true;
    //   }
    //   if (style!.blendMode != null) {
    //     // blendingPaint.blendMode = style!.blendMode!;
    //     needsSaveLayer = true;
    //   }
    //   if (needsSaveLayer) {
    //     canvas.saveLayer(null, blendingPaint);
    //   }

    //   for (Drawable child in children!) {
    //     child.write();
    //   }

    //   if (style!.mask != null) {
    //     canvas.saveLayer(null, _grayscaleDstInPaint);
    //     style!.mask!.write();
    //     canvas.restore();
    //   }
    //   if (needsSaveLayer) {
    //     canvas.restore();
    //   }
    //   if (transform != null) {
    //     canvas.restore();
    //   }
    // };

    // if (style?.clipPath?.isNotEmpty == true) {
    //   for (Path clipPath in style!.clipPath!) {
    //     canvas.save();
    //     canvas.clipPath(clipPath);
    //     if (children!.length > 1) {
    //       canvas.saveLayer(null, ui.Paint());
    //     }

    //     innerDraw();

    //     if (children!.length > 1) {
    //       canvas.restore();
    //     }
    //     canvas.restore();
    //   }
    // } else {
    //   innerDraw();
    // }
  }

  @override
  DrawableGroup mergeStyle(DrawableStyle newStyle) {
    final DrawableStyle mergedStyle = DrawableStyle.mergeAndBlend(
      style,
      fill: newStyle.fill,
      stroke: newStyle.stroke,
      clipPath: newStyle.clipPath,
      // dashArray: newStyle.dashArray,
      // dashOffset: newStyle.dashOffset,
      pathFillType: newStyle.pathFillType,
      // textStyle: newStyle.textStyle,
    );

    final List<Drawable> mergedChildren =
        children!.map<Drawable>((Drawable child) {
      if (child is DrawableStyleable) {
        return child.mergeStyle(mergedStyle);
      }
      return child;
    }).toList();

    return DrawableGroup(
      id,
      mergedChildren,
      mergedStyle,
      transform: transform,
    );
  }
}

// /// A raster image (e.g. PNG, JPEG, or GIF) embedded in the drawable.
// class DrawableRasterImage implements DrawableStyleable {
//   /// Creates a new [DrawableRasterImage].
//   const DrawableRasterImage(
//     this.id,
//     this.image,
//     this.offset,
//     this.style, {
//     this.size,
//     this.transform,
//   });

//   @override
//   final String? id;

//   /// The [Image] to draw.
//   final ui.Image image;

//   /// The position for the top-left corner of the image.
//   final Point offset;

//   /// The size to scale the image to.
//   final Point? size;

//   @override
//   final AffineMatrix? transform;

//   @override
//   final DrawableStyle style;

//   @override
//   void write() {
//     dynamic canvas;
//     final Point imageSize = Point(
//       image.width.toDouble(),
//       image.height.toDouble(),
//     );
//     Point? desiredSize = imageSize;
//     double scale = 1.0;
//     if (size != null) {
//       desiredSize = size;
//       scale = math.min(
//         size!.x / image.width,
//         size!.y / image.height,
//       );
//     }
//     if (scale != 1.0 || offset != Point.zero || transform != null) {
//       final Point halfDesiredSize = desiredSize! / 2.0;
//       final Point scaledHalfImageSize = imageSize * scale / 2.0;
//       final Point shift = Point(
//         halfDesiredSize.x - scaledHalfImageSize.x,
//         halfDesiredSize.y - scaledHalfImageSize.y,
//       );
//       canvas.save();
//       canvas.translate(offset.x + shift.x, offset.y + shift.y);
//       canvas.scale(scale, scale);
//       if (transform != null) {
//         canvas.transform(transform!);
//       }
//     }
//     canvas.drawImage(image, Point.zero, ui.Paint());
//     if (scale != 1.0 || offset != Point.zero || transform != null) {
//       canvas.restore();
//     }
//   }

//   @override
//   bool get hasDrawableContent => image.height > 0 && image.width > 0;

//   @override
//   DrawableRasterImage mergeStyle(DrawableStyle newStyle) {
//     return DrawableRasterImage(
//       id,
//       image,
//       offset,
//       DrawableStyle.mergeAndBlend(
//         style,
//         fill: newStyle.fill,
//         stroke: newStyle.stroke,
//         clipPath: newStyle.clipPath,
//         mask: newStyle.mask,
//         dashArray: newStyle.dashArray,
//         dashOffset: newStyle.dashOffset,
//         pathFillType: newStyle.pathFillType,
//         textStyle: newStyle.textStyle,
//       ),
//       size: size,
//       transform: transform,
//     );
//   }
// }

/// Represents a drawing element that will be rendered to the canvas.
class DrawableShape implements DrawableStyleable {
  /// Creates a new [DrawableShape].
  const DrawableShape(this.id, this.path, this.style, {this.transform});

  @override
  final String? id;

  @override
  final AffineMatrix? transform;

  @override
  final DrawableStyle style;

  /// The [Path] describing this shape.
  final Path path;

  /// The bounds of this shape.
  Rect get bounds => path.getBounds();

  // can't use bounds.isEmpty here because some paths give a 0 width or height
  // see https://skia.org/user/api/SkPath_Reference#SkPath_getBounds
  // can't rely on style because parent style may end up filling or stroking
  // TODO(dnfield): implement display properties - but that should really be done on style.
  @override
  bool get hasDrawableContent => bounds.width + bounds.height > 0;

  @override
  void write(Set<Paint> paints, Set<Path> paths, List<DrawCommand?> commands,
      AffineMatrix currentTransform) {
    if (transform != null) {
      currentTransform = currentTransform.multiplied(transform!);
    }
    final Paint? fillPaint = style.fill?.toPaint();
    final Paint? strokePaint = style.stroke?.toPaint();
    final Path transformedPath = path.transformed(currentTransform);

    bool usedPath = false;
    if (fillPaint != null) {
      // Convert fills into vertices, avoid adding if degenerates to empty.
      final vertices = convertPathToVertices(transformedPath);
      if (vertices.isNotEmpty) {
        // paints.add(fillPaint);
        commands.add(DrawVerticesCommand(
          vertices,
          null,
          Int32List.fromList(
            List<int>.filled(
              vertices.length ~/ 2,
              fillPaint.color.value,
            ),
          ),
          null,
        ));
      }
    }
    if (strokePaint != null) {
      usedPath = true;
      paints.add(strokePaint);
      // print(
      //     'canvas.drawPath(path${transformedPath.hashCode}, paint${strokePaint.hashCode});');
      commands.add(DrawPathCommand(transformedPath, strokePaint));
    }
    if (usedPath) {
      paths.add(transformedPath);
    }
    return;
    // if (!hasDrawableContent) {
    //   return;
    // }

    // path.fillType = style.pathFillType ?? PathFillType.nonZero;
    // // if we have multiple clips to apply, need to wrap this in a loop.
    // final Function innerDraw = () {
    //   if (transform != null) {
    //     canvas.save();
    //     canvas.transform(transform!);
    //   }
    //   if (style.blendMode != null) {
    //     canvas.saveLayer(null, ui.Paint()..blendMode = style.blendMode!);
    //   }
    //   if (style.mask != null) {
    //     canvas.saveLayer(null, ui.Paint());
    //   }
    //   if (style.fill?.style != null) {
    //     assert(style.fill!.style == ui.PaintingStyle.fill);
    //     canvas.drawPath(path, style.fill!.toFlutterPaint());
    //   }

    //   if (style.stroke?.style != null) {
    //     assert(style.stroke!.style == ui.PaintingStyle.stroke);
    //     if (style.dashArray != null &&
    //         !identical(style.dashArray, DrawableStyle.emptyDashArray)) {
    //       // canvas.drawPath(
    //       //     dashPath(
    //       //       path,
    //       //       dashArray: style.dashArray!,
    //       //       dashOffset: style.dashOffset,
    //       //     ),
    //       //     style.stroke!.toFlutterPaint());
    //     } else {
    //       canvas.drawPath(path, style.stroke!.toFlutterPaint());
    //     }
    //   }

    //   if (style.mask != null) {
    //     canvas.saveLayer(null, _grayscaleDstInPaint);
    //     style.mask!.write();
    //     canvas.restore();
    //     canvas.restore();
    //   }

    //   if (style.blendMode != null) {
    //     canvas.restore();
    //   }
    //   if (transform != null) {
    //     canvas.restore();
    //   }
    // };

    // if (style.clipPath?.isNotEmpty == true) {
    //   for (Path clip in style.clipPath!) {
    //     canvas.save();
    //     canvas.clipPath(clip);
    //     innerDraw();
    //     canvas.restore();
    //   }
    // } else {
    //   innerDraw();
    // }
  }

  @override
  DrawableShape mergeStyle(DrawableStyle newStyle) {
    return DrawableShape(
      id,
      path,
      DrawableStyle.mergeAndBlend(
        style,
        fill: newStyle.fill,
        stroke: newStyle.stroke,
        clipPath: newStyle.clipPath,
        mask: newStyle.mask,
        // dashArray: newStyle.dashArray,
        // dashOffset: newStyle.dashOffset,
        pathFillType: newStyle.pathFillType,
        // textStyle: newStyle.textStyle,
      ),
      transform: transform,
    );
  }
}

// abstract class PathMovement {
//   PathMovement transform(Float64List matrix4);
// }

// class MoveToCommand extends PathMovement {
//   const MoveToCommand(this.x, this.y);

//   final double dx;
//   final double dy;
// }

// class DrawPath {

//   /// The backing path;
//   final ui.Path path = ui.Path();
//   final List<MoveToCommand> pathCommands = <MoveToCommand>[];

//   void moveTo(double dx, double dy) {
//     path.moveTo(dx, dy);
//     pathCommands.add(MoveToCommand(dx, dy));
//   }

//   Rect getBounds() => path.getBounds();

//   transform(Float64List matrix4) {
//     PathMetricIterator
//     var newPathCommands = pathCommands.map((x) => x.t)
//   }
// }

/// Scales a matrix to the given [viewBox] based on the [desiredSize]
/// of the widget.
///
/// Returns true if the supplied matrix was modified.
bool scaleCanvasToViewBox2(
  Matrix4 matrix,
  Point desiredSize,
  Rect viewBox,
  Point pictureSize,
) {
  if (desiredSize == viewBox.size) {
    return false;
  }
  final double scale = math.min(
    desiredSize.x / viewBox.width,
    desiredSize.y / viewBox.height,
  );
  final Point scaledHalfViewBoxSize = viewBox.size * scale / 2.0;
  final Point halfDesiredSize = desiredSize / 2.0;
  final Point shift = Point(
    halfDesiredSize.x - scaledHalfViewBoxSize.x,
    halfDesiredSize.y - scaledHalfViewBoxSize.y,
  );
  matrix
    ..translate(shift.x, shift.y)
    ..scale(scale, scale);
  return true;
}
