# neurozerox/demo — Juego arcade para WASM-4

Pequeño juego arcade escrito en [MoonBit](https://www.moonbitlang.com/) para la
fantasy console [WASM-4](https://wasm4.org/). Controlas un cuadrado que recolecta
monedas mientras esquiva a un enemigo que rebota por la pantalla, todo contra reloj.

## Cómo se juega

- Mueve al jugador con las **flechas** y recolecta monedas.
- Cada moneda te da **+1 punto**, **+5 segundos** de tiempo y **sube la velocidad**.
- Si tocas al enemigo, es **Game Over**.
- Si el temporizador llega a 0, también es **Game Over**.
- En los **últimos 5 segundos** la pantalla parpadea como aviso de urgencia.
- En la pantalla de Game Over, presiona **Z** para reiniciar.

### Controles

| Acción            | Tecla            |
| ----------------- | ---------------- |
| Mover             | Flechas ← ↑ ↓ →  |
| Reiniciar partida | Z (en Game Over) |

> El movimiento admite diagonales (puedes presionar dos direcciones a la vez).

## Requisitos

- [MoonBit toolchain](https://www.moonbitlang.com/download/) (`moon`).
- [Node.js](https://nodejs.org/) para ejecutar el runtime de WASM-4 vía `npx`
  (o instala la CLI `w4` de [WASM-4](https://wasm4.org/docs/getting-started/setup)).

## Compilar

```bash
# Instala la dependencia de WASM-4 (la primera vez)
moon install

# Compila el cart en release
moon build --target wasm --release
```

El cart resultante queda en:

```
_build/wasm/release/build/demo.wasm
```

## Ejecutar

```bash
# Levanta el runtime de WASM-4 y abre el juego en el navegador
npx wasm4 run _build/wasm/release/build/demo.wasm
```

Luego abre la URL que muestra la consola (por defecto http://localhost:4444).

## Desarrollo

```bash
moon check                 # Linter / type-check
moon test                  # Tests
moon fmt                   # Formatea el código (convención ///| de MoonBit)
moon build --target wasm --release
```

> Nota: `moon test` falla con `Import "env"` porque el cart importa el entorno
> host de WASM-4 (`env.memory`), que el runner genérico de MoonBit no provee. Eso
> es esperado: el juego se prueba ejecutándolo en el runtime de WASM-4, no con
> `moonrun`.

## Estructura

| Archivo         | Descripción                                              |
| --------------- | ------------------------------------------------------- |
| `demo.mbt`      | Lógica del juego (`start`, `update`, sprites, colisión) |
| `demo_test.mbt` | Tests del paquete                                        |
| `cmd/main/`     | Punto de entrada que enlaza el cart                      |
| `moon.pkg`      | Configuración del paquete y opciones de enlace          |
| `moon.mod.json` | Metadatos del módulo y dependencias                     |

## Licencia

[Apache-2.0](LICENSE).
