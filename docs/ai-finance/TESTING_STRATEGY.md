# Testing strategy

Pure money tests live in `apps/api/src/finance/engine.spec.ts`. They cover lending kept out of balance, a monthly plan, estimated income left out of the projection, safe-to-spend arithmetic, a null health component, a thin history that does not flag, and a purchase what-if.

`advisor.graph.spec.ts` checks that tool arguments reject `userId`, that a Malayalam spending answer uses the tool amount, and that an invented rupee figure is replaced.

Run from `apps/api`:

```
npx vitest run
npx tsc -p tsconfig.build.json --noEmit
```

Flutter:

```
flutter analyze lib/screens/intelligence_screen.dart lib/screens/shell.dart lib/api/finance_api.dart
```

The full `flutter test` binary has been missing in this environment, so widget tests were not executed. Analyzer is the check that ran.

Do not add a test that calls Groq. The graph spec uses a fake explainer.
