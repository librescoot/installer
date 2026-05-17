enum SubstepState { pending, active, done, failed }

class Substep {
  Substep({
    required this.id,
    required this.label,
    this.state = SubstepState.pending,
    this.detail,
  });

  final String id;
  final String label;
  final SubstepState state;
  final String? detail;

  Substep copyWith({SubstepState? state, String? detail, String? label}) {
    return Substep(
      id: id,
      label: label ?? this.label,
      state: state ?? this.state,
      detail: detail ?? this.detail,
    );
  }
}
