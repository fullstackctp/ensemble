import 'dart:developer';

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:ensemble/model/pull_to_refresh.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// a wrapper around a scrollable widget to support pull to refresh
class PullToRefreshContainer extends StatefulWidget {
  const PullToRefreshContainer(
      {super.key,
      required this.contentWidget,
      this.refreshWidget,
      this.options,
      required this.onRefresh});

  final Widget contentWidget;
  final Future<void> Function() onRefresh;

  // TODO: size the refresh widget properly before expose it.
  final Widget? refreshWidget;
  final PullToRefreshOptions? options;

  @override
  State<PullToRefreshContainer> createState() => _PullToRefreshContainerState();
}

class _PullToRefreshContainerState extends State<PullToRefreshContainer> {
  static const double _defaultIndicatorSize = 30;

  @override
  Widget build(BuildContext context) {
    return CustomRefreshIndicator(
        offsetToArmed: _defaultIndicatorSize,
        onRefresh: processOnRefresh,
        builder: (context, child, controller) => Stack(
              children: [
                if (!controller.isIdle && !controller.isCanceling)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                          //height: _defaultIndicatorSize * controller.value,
                          width: double.infinity,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(),
                          child: widget.refreshWidget ??
                              SizedBox(
                                  width: _defaultIndicatorSize,
                                  height: _defaultIndicatorSize,
                                  child: getProgressIndicator(controller)))
                    ],
                  ),

                // this is the content widget (which slides down as the progress widget appears)
                Transform.translate(
                    offset: Offset(0, _defaultIndicatorSize * controller.value),
                    child: child)
              ],
            ),
        child: widget.contentWidget);
  }

  Widget getProgressIndicator(IndicatorController controller) {
    if (widget.options?.indicatorType == RefreshIndicatorType.cupertino) {
      return controller.isDragging || controller.isArmed
          ? CupertinoActivityIndicator.partiallyRevealed(
              progress: controller.value.clamp(0, 1),
              radius: _defaultIndicatorSize / 2)
          : const CupertinoActivityIndicator(radius: _defaultIndicatorSize / 2);
    } else {
      // default to Material theme
      return CircularProgressIndicator(
          value: controller.isDragging || controller.isArmed
              ? controller.value.clamp(0, 1)
              : null);
    }
  }

  Future<void> processOnRefresh() async {
    // wait for the callback to return
    await widget.onRefresh();

    // await Future.delayed(Duration(seconds: 2));
  }
}
