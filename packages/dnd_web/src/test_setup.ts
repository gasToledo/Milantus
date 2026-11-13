import { cleanup } from '@testing-library/react';
import { afterEach } from 'vitest';

// Sin `globals` de Vitest, Testing Library no desmonta sola entre pruebas y
// el documento se llena con la anterior.
afterEach(() => {
  cleanup();
});
