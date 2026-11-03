import 'package:flutter/material.dart';

class ColorPicker extends StatefulWidget {
  final double buttonSize;
  final double padSize;
  final MaterialColor initialColor;
  final List<MaterialColor> availableColors = Colors.primaries;
  final ValueChanged<MaterialColor> onChanged;

  const ColorPicker({
    super.key,
    required this.initialColor,
    required this.onChanged,
    this.buttonSize = 30,
    this.padSize = 60,
  });

  @override
  State<StatefulWidget> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  bool isOpen = false;
  late MaterialColor chosenColor;

  @override
  void initState() {
    chosenColor = widget.initialColor;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        TapRegion(
          onTapInside: (event) {
            setState(() {
              isOpen = true;
            });
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: .circular(3),
              border: BoxBorder.all(color: Colors.black, width: 1),
              color: chosenColor,
            ),
            child: SizedBox(
              width: widget.buttonSize,
              height: widget.buttonSize,
            ),
          ),
        ),
        Positioned(
          child: Visibility(
            visible: isOpen,
            child: Stack(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: .circular(3),
                    border: BoxBorder.all(color: Colors.black, width: 1),
                    color: Colors.white,
                  ),
                  child: Padding(
                    padding: const .fromLTRB(20, 40, 20, 0),
                    child: GridView.extent(
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      shrinkWrap: true,
                      maxCrossAxisExtent: widget.padSize,
                      children: widget.availableColors.map((color) {
                        return TapRegion(
                          onTapInside: (event) {
                            setState(() {
                              isOpen = false;
                              chosenColor = color;
                            });
                            widget.onChanged(color);
                          },
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: .circular(100),
                              color: color,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        isOpen = false;
                      });
                    },
                    child: const Align(
                      alignment: Alignment.topRight,
                      child: Icon(Icons.close),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
