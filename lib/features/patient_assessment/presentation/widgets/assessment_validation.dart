import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/assessment_enums.dart';

enum AssessmentValidationTarget {
  age,
  sex,
  occurrenceType,
  mechanism,
  injurySites,
  onsetAt,
  primarySymptom,
  classification,
  preKtas,
  exceptionReason,
  exceptionDetail,
  avpu,
  unassessableReason,
  bloodPressure,
  pulse,
  respiratoryRate,
  temperature,
  oxygenSaturation,
  treatments,
  pupils,
  callbackContact,
}

GlobalKey<State<StatefulWidget>> assessmentValidationKey(
  AssessmentValidationTarget target,
) => GlobalObjectKey<State<StatefulWidget>>(target);

AssessmentValidationTarget validationTargetForVital(VitalType type) {
  return switch (type) {
    VitalType.bloodPressure => AssessmentValidationTarget.bloodPressure,
    VitalType.pulse => AssessmentValidationTarget.pulse,
    VitalType.respiratoryRate => AssessmentValidationTarget.respiratoryRate,
    VitalType.temperature => AssessmentValidationTarget.temperature,
    VitalType.oxygenSaturation => AssessmentValidationTarget.oxygenSaturation,
  };
}

class AssessmentValidationSection extends StatelessWidget {
  const AssessmentValidationSection({
    super.key,
    required this.target,
    required this.activeTarget,
    required this.message,
    required this.child,
  });

  final AssessmentValidationTarget target;
  final AssessmentValidationTarget? activeTarget;
  final String? message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool showMessage = activeTarget == target && message != null;
    return Container(
      key: assessmentValidationKey(target),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          child,
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: showMessage
                ? Padding(
                    key: const Key('assessmentInlineValidationMessage'),
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.negativeBackground,
                        border: Border.all(color: AppColors.negativeBorder),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 19,
                            color: AppColors.statusNegative,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              message!,
                              style: const TextStyle(
                                color: AppColors.statusNegative,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
