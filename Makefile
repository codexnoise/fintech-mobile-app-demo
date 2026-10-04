# Atajos del monorepo. Requiere FVM (Flutter 3.47.4) y Node 22.
MEMBERS := packages/core packages/design_system packages/sdui_engine apps/mobile

.PHONY: get format analyze test coverage functions-test check

get:
	fvm dart pub get

format:
	fvm dart format .

analyze:
	fvm flutter analyze $(MEMBERS)

test:
	@set -e; for m in $(MEMBERS); do echo "== $$m"; (cd $$m && fvm flutter test); done

coverage:
	@set -e; for m in $(MEMBERS); do (cd $$m && fvm flutter test --coverage); done

functions-test:
	cd backend/functions && npm test

check: format analyze test functions-test
