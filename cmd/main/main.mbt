// DECLARACIONES
pub struct Player {
  mut x : Int
  mut y : Int
}

priv struct Enemy {
  mut x : Int
  mut y : Int
}

priv struct GameState {
  mut x : Int
  mut y : Int
}
priv struct Stats {
  mut puntaje : Int
  mut velocidad : Int
}
priv struct RandomSeed {
  mut seed : Int
}
priv struct GameStateFlags { // Para manejar el estado de la partida
  mut is_playing : Bool
}

let screen_max = 160
let jugador : Player = { x: 0, y: 0 }
let enemigo : Enemy = { x: 150, y: 70 }
let moneda : GameState = { x: 100, y: 50 }
let estado : Stats = { puntaje: 0, velocidad: 1 }
let rand_state : RandomSeed = { seed: 123 } // Inicializa la semilla
let game_flags : GameStateFlags = { is_playing: true }

// FUNCIONES
// Generador Pseudoaleatorio Simple (LCG)
fn next_random(seed: Int) -> Int {
  // LCG: Multiplicador (1664525) * Semilla + Incremento (1013904223)
  // El resultado se toma módulo 2^32 (lo que hace Int por defecto)
  let result = (seed * 1664525 + 1013904223)
  // Devolvemos el resultado y lo limitamos al rango [0, 160]
  // La división por 16000 es una forma simple de reducir el valor y obtener un número pequeño.
  // Usamos el operador de módulo (%) para el resto de la división.
  result % screen_max
}

// Generador de posición segura, que respeta el tamaño de la moneda (8px)
fn get_safe_random_coord(seed: Int, sprite_size: Int) -> Int {
    let max_coord = screen_max - sprite_size
    // Genera un número aleatorio y asegura que no exceda el límite máximo de dibujo.
    next_random(seed) % (max_coord + 1)
}


// CUERPO
pub fn start() -> Unit {
}
pub fn update() -> Unit {
  let player_w = 16 // Ancho del jugador
  let player_h = 16 // Alto del jugador
  let coin_w = 8 // Ancho de moneda
  let coin_h = 8 // Alto de moneda

  // Declara el estado del mando SÓLO UNA VEZ al inicio de update()
  let gamepad = @wasm4.get_gamepad(index=1)

    // lógica de movimiento del cuadrado
  if gamepad.button_right && jugador.x + player_w < screen_max {
    jugador.x += estado.velocidad
  } else if gamepad.button_down && jugador.y + player_h < screen_max {
    jugador.y += estado.velocidad
  } else if gamepad.button_left && jugador.x >= 0 {
    jugador.x -= estado.velocidad
  } else if gamepad.button_up && jugador.y >= 0 {
    jugador.y -= estado.velocidad
  }

  // Lógica de colisión
  if jugador.x < moneda.x + coin_w && 
     jugador.x + player_w > moneda.x && 
     jugador.y < moneda.y + coin_w && 
     jugador.y + player_w > moneda.y {
    estado.velocidad += 1  
    estado.puntaje += 1
    moneda.x = get_safe_random_coord(rand_state.seed, coin_w)
    rand_state.seed = moneda.x
    moneda.y = get_safe_random_coord(rand_state.seed, coin_h)
    rand_state.seed = moneda.y
  }

  @wasm4.set_draw_colors(2)
  @wasm4.rect(jugador.x, jugador.y, player_w, player_h)
  @wasm4.set_draw_colors(3)
  @wasm4.rect(moneda.x, moneda.y, coin_w, coin_h) 

  let score_text = "PUNTAJE: " + estado.puntaje.to_string()
  @wasm4.set_draw_colors(4)
  @wasm4.text(score_text, 5, 5) 

}