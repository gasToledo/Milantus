import { cleanup } from '@testing-library/react';
import { afterEach } from 'vitest';

// Sin `globals` de Vitest, Testing Library no desmonta sola entre pruebas y
// el documento se llena con la anterior.
afterEach(() => {
  cleanup();
});

// jsdom no trae lo que las pantallas usan para moverse: «reducir movimiento»,
// las animaciones de Web Animations y el scroll de un elemento. Un doble que
// no hace nada alcanza (las pruebas no miran movimiento) y evita que cada
// pantalla tenga que preguntar si existen. Solo si faltan: un jsdom que los
// traiga usa los suyos.
window.matchMedia ??= (query: string) =>
  ({
    matches: false,
    media: query,
    onchange: null,
    addListener: () => {},
    removeListener: () => {},
    addEventListener: () => {},
    removeEventListener: () => {},
    dispatchEvent: () => false,
  }) as MediaQueryList;
Element.prototype.animate ??= function () {
  return { cancel: () => {}, finished: Promise.resolve() } as unknown as Animation;
};
Element.prototype.scrollTo ??= () => {};
Element.prototype.scrollIntoView ??= () => {};
