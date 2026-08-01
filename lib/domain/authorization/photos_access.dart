/// Product-facing Photos library authorization state (ADR-K / Cap 5.2).
///
/// Maps from Pigeon [AuthStatus]: wire `authorized` → [full].
enum PhotosAccess {
  notDetermined,
  full,
  limited,
  denied,
  restricted,
}
