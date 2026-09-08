import 'fake_saved_pool_repository.dart';
import 'saved_pool_repository_contract.dart';

void main() {
  savedPoolRepositoryContract(
    'FakeSavedPoolRepository',
    ({required clock, required createId}) {
      return FakeSavedPoolRepository(clock: clock, createId: createId);
    },
  );
}
