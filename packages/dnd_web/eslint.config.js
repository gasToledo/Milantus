import reactHooks from 'eslint-plugin-react-hooks';
import tseslint from 'typescript-eslint';

// TypeScript 7 no trae API. `typescript` es `@typescript/typescript6` (el parser
// la importa; su bin es `tsc6`) y `tsc` sigue siendo el 7, en `@typescript/native`.
export default tseslint.config(
  {
    ignores: ['dist/**', 'src/engine/dnd_engine.generated.js', 'playwright-report/**', 'test-results/**', 'coverage/**'],
  },
  ...tseslint.configs.recommended,
  reactHooks.configs.flat.recommended,
  {
    rules: {
      // `tsc` ya cubre lo que no se usa y el código usa `any` en el borde del
      // motor. El resto de estas son estilo, no un hook mal cerrado.
      '@typescript-eslint/no-explicit-any': 'off',
      '@typescript-eslint/no-unused-vars': 'off',
      '@typescript-eslint/no-empty-object-type': 'off',
      '@typescript-eslint/ban-ts-comment': 'off',
      '@typescript-eslint/no-namespace': 'off',
      '@typescript-eslint/triple-slash-reference': 'off',
      // El plugin trae las reglas del React Compiler. Esta base setea estado
      // en efectos a propósito (el foco diferido, la ronda del Quiz, los
      // tutoriales) y reescribirlo cambiaría el comportamiento. Se dejan las
      // dos que cazan un hook mal cerrado o una dependencia vieja.
      'react-hooks/exhaustive-deps': 'error',
      'react-hooks/static-components': 'off',
      'react-hooks/use-memo': 'off',
      'react-hooks/preserve-manual-memoization': 'off',
      'react-hooks/incompatible-library': 'off',
      'react-hooks/immutability': 'off',
      'react-hooks/globals': 'off',
      'react-hooks/refs': 'off',
      'react-hooks/set-state-in-effect': 'off',
      'react-hooks/error-boundaries': 'off',
      'react-hooks/purity': 'off',
      'react-hooks/set-state-in-render': 'off',
      'react-hooks/unsupported-syntax': 'off',
      'react-hooks/config': 'off',
      'react-hooks/gating': 'off',
    },
  },
);
