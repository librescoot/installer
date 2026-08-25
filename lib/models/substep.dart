/// [degraded] is a step that did not complete but has a working fallback, so
/// the run continues by another route. Distinct from [failed], which is a step
/// whose absence stops the thing that depends on it.
enum SubstepState { pending, active, done, degraded, failed }

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
