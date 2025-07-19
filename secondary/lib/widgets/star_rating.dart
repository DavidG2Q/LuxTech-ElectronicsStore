import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  final Function(double)? onRatingChanged;
  final bool isEnabled;

  const StarRating({
    Key? key,
    required this.rating,
    this.size = 24.0,
    this.onRatingChanged,
    this.isEnabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: (!isEnabled || onRatingChanged == null) ? null : () => onRatingChanged!(index + 1),
          child: Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: index < rating
                ? Colors.amber
                : Colors.grey[400],
            size: size,
          )
        );
      }),
    );
  }
}