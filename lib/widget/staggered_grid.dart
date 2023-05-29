import 'dart:math';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class EnsembleStaggeredGrid extends StatefulWidget
    with
        Invokable,
        UpdatableContainer,
        HasController<StaggeredGridController, EnsembleStaggeredGridState> {
  static const type = 'StaggeredGrid';

  EnsembleStaggeredGrid({Key? key}) : super(key: key);

  final StaggeredGridController _controller = StaggeredGridController();
  @override
  StaggeredGridController get controller => _controller;

  @override
  State<StatefulWidget> createState() => EnsembleStaggeredGridState();

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'horizontalGap': (value) =>
          _controller.horizontalGap = Utils.optionalDouble(value),
      'verticalGap': (value) =>
          _controller.verticalGap = Utils.optionalDouble(value),
      'onItemTap': (funcDefinition) => _controller.onItemTap =
          EnsembleAction.fromYaml(funcDefinition, initiator: this),
    };
  }

  @override
  Map<String, Function> methods() {
    // TODO: implement methods
    throw UnimplementedError();
  }

  @override
  void initChildren({List<Widget>? children, ItemTemplate? itemTemplate}) {
    _controller.children = children;
    _controller.itemTemplate = itemTemplate;
  }
}

class EnsembleStaggeredGridState extends WidgetState<EnsembleStaggeredGrid>
    with TemplatedWidgetState {
  List<Widget>? templatedChildren;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // evaluate item-template's initial value & listen for changes
    if (widget._controller.itemTemplate != null) {
      registerItemTemplate(context, widget._controller.itemTemplate!,
          evaluateInitialValue: true, onDataChanged: (List dataList) {
        setState(() {
          templatedChildren = buildWidgetsFromTemplate(
              context, dataList, widget._controller.itemTemplate!);
        });
      });
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    final items = buildItems();

    return SingleChildScrollView(
      child: StaggeredGrid.count(
        crossAxisCount: 4,
        mainAxisSpacing: widget._controller.verticalGap ?? 0,
        crossAxisSpacing: widget._controller.horizontalGap ?? 0,
        children: List.generate(items.length, (index) {
          final item = items[index];

          return StaggeredGridTile.count(
            crossAxisCellCount: 2,
            mainAxisCellCount: getRandomMainAxisCount,
            child: GestureDetector(
              onTap: () => _onItemTapped(index),
              child: item,
            ),
          );
        }),
      ),
    );
  }

  int get getRandomMainAxisCount {
    return Random().nextInt(3) + 2;
  }

  List<Widget> buildItems() {
    // children will be rendered before templated children
    List<Widget> children = [];
    if (widget._controller.children != null) {
      children.addAll(widget._controller.children!);
    }
    if (templatedChildren != null) {
      children.addAll(templatedChildren!);
    }

    return children;
  }

  void _onItemTapped(int index) {
    if (widget._controller.onItemTap != null) {
      ScreenController().executeAction(
        context,
        widget._controller.onItemTap!,
        event: EnsembleEvent(widget, data: {'selectedItemIndex': index}),
      );
    }
  }
}

class StaggeredGridController extends BoxController {
  double? horizontalGap;
  double? verticalGap;

  List<Widget>? children;
  ItemTemplate? itemTemplate;
  EnsembleAction? onItemTap;
}
