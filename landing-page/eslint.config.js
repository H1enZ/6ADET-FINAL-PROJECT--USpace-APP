import js from '@eslint/js';
import globals from 'globals';

export default [
  { ignores: ['dist/**', 'node_modules/**', 'test-results/**', 'playwright-report/**', 'qa/**'] },
  js.configs.recommended,
  { files: ['**/*.js'], languageOptions: { globals: { ...globals.browser, ...globals.node } } },
  { files: ['scripts/**/*.mjs'], languageOptions: { globals: globals.node } },
];
