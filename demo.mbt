// DECLARACIONES
pub struct Player {
  mut x : Int
  mut y : Int
}

priv struct Enemy {
  mut x : Int
  mut y : Int
  mut dir_x : Int
  mut dir_y : Int
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
  mut frame_counter : Int
}
priv struct GameStateFlags { // Para manejar el estado de la partida
  mut is_playing : Bool
}

let screen_max = 160
let jugador : Player = { x: 0, y: 0 }
let enemigo : Enemy = { x: 150, y: 70, dir_x: -1, dir_y: 1 }
let moneda : GameState = { x: 100, y: 50 }
let estado : Stats = { puntaje: 0, velocidad: 1 }
let rand_state : RandomSeed = { seed: 123, frame_counter: 0 } // Inicializa la semilla
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

//Reiniciar juego
fn reset_game() -> Unit {
    // Reinicia todas las variables mutables a sus valores iniciales
    jugador.x = 0
    jugador.y = 0
    
    enemigo.x = 150
    enemigo.y = 70
    
    estado.puntaje = 0
    estado.velocidad = 1
    
    // Y lo más importante: ¡Activa el juego de nuevo!
    game_flags.is_playing = true
}


// CUERPO
pub fn start() -> Unit {
}
pub fn update() -> Unit {
  let player_w = 16 // Ancho del jugador
  let player_h = 16 // Alto del jugador
  let coin_w = 8 // Ancho de moneda
  let coin_h = 8 // Alto de moneda
  let gamepad = @wasm4.get_gamepad(index=1)

  if game_flags.is_playing {

    // 1. MOVIMIENTO HORIZONTAL Y REBOTE (SUAVE)
    let current_player_speed = estado.velocidad
    let enemy_horizontal_speed = current_player_speed + 1 
    let enemy_w = 12 // Asumimos un tamaño de enemigo

    // Aplica el movimiento: (posición += dirección * velocidad)
    enemigo.x += enemigo.dir_x * enemy_horizontal_speed 

    // Lógica de REBOTE HORIZONTAL
    if enemigo.x + enemy_w >= screen_max {
      enemigo.dir_x = -1 // Toca el borde derecho, ahora va a la IZQUIERDA
      // DESVÍO VERTICAL LEVE: Inyecta un pequeño cambio aleatorio en Y.
      // Generamos un número (ej. 0 a 7) y lo sumamos a Y.
      let offset = next_random(rand_state.seed) % 8
      rand_state.seed = offset // Actualiza la semilla
      enemigo.y += offset
    } else if enemigo.x <= 0 {
      enemigo.dir_x = 1  // Toca el borde izquierdo, ahora va a la DERECHA
      // DESVÍO VERTICAL LEVE: Inyecta un pequeño cambio aleatorio en Y.
      let offset = next_random(rand_state.seed) % 8
      rand_state.seed = offset
      enemigo.y += offset
    }


    // 2. MOVIMIENTO VERTICAL (ZIG-ZAG) Y REBOTE PURO
    let enemy_speed_y = 1
    let enemy_h = 12 
    
    enemigo.y += enemigo.dir_y * enemy_speed_y // Aplica el zig-zag

    // Lógica de REBOTE VERTICAL CON RUIDO ALEATORIO
    if enemigo.y + enemy_h >= screen_max {
      enemigo.dir_y = -1 // Toca el fondo, ahora va ARRIBA
    } else if enemigo.y <= 0 {
      enemigo.dir_y = 1  // Toca el techo, ahora va ABAJO
    }

    // lógica de movimiento del jugador
    if gamepad.button_right && jugador.x + player_w < screen_max {
      jugador.x += estado.velocidad
    } else if gamepad.button_down && jugador.y + player_h < screen_max {
      jugador.y += estado.velocidad
    } else if gamepad.button_left && jugador.x >= 0 {
      jugador.x -= estado.velocidad
    } else if gamepad.button_up && jugador.y >= 0 {
      jugador.y -= estado.velocidad
    }

    // Lógica de colisión monedas
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

    // --- LÓGICA DE COLISIÓN CON ENEMIGO (Game Over) ---
    let enemy_w = 12 // Asumimos un tamaño de enemigo
    let enemy_h = 12 

    if jugador.x < enemigo.x + enemy_w && 
       jugador.x + player_w > enemigo.x && 
       jugador.y < enemigo.y + enemy_h && 
       jugador.y + player_h > enemigo.y {
      
      game_flags.is_playing = false // ¡Game Over!
    }

    // --- DIBUJO ---
    @wasm4.set_draw_colors(2)
    @wasm4.rect(jugador.x, jugador.y, player_w, player_h)
    
    @wasm4.set_draw_colors(4) // Nuevo color para el enemigo (ejemplo)
    @wasm4.rect(enemigo.x, enemigo.y, enemy_w, enemy_h) 

    @wasm4.set_draw_colors(3)
    @wasm4.rect(moneda.x, moneda.y, coin_w, coin_h) 

    let score_text = "PUNTAJE: " + estado.puntaje.to_string()
    @wasm4.set_draw_colors(4)
    @wasm4.text(score_text, 5, 5) 

  } else {
    // PANTALLA DE GAME OVER
    @wasm4.set_draw_colors(1)
    @wasm4.text("GAME OVER!", 40, 70)
    
    @wasm4.set_draw_colors(3)
    let final_score = "Puntaje: " + estado.puntaje.to_string()
    @wasm4.text(final_score, 40, 90)


    // --- LÓGICA DE PARPADEO ---
    rand_state.frame_counter += 1 // Suma 1 cada frame (60 veces por segundo)

      // Resetea el contador para evitar overflow (no estrictamente necesario pero es buena práctica)
    if rand_state.frame_counter > 90 { 
        rand_state.frame_counter = 0 
    }

    // Si el contador de frames dividido por 30 (medio segundo) tiene un resto menor a 15 (un cuarto de segundo), dibujar.
    if rand_state.frame_counter % 90 < 45 { 
      @wasm4.text("Presiona Z", 40, 110)
      @wasm4.text("para reiniciar", 25, 120)
    }

    // --- LÓGICA DE REINICIO ---
    let gamepad = @wasm4.get_gamepad(index=1)
    
    // Verifica si se presiona el botón 'Z' (BTN2/BUTTON_X/BUTTON_1 en la API)
    if gamepad.button_2 { // button_2 corresponde a 'Z' en WASM-4
        reset_game() // Llama a la función de reinicio
    }

  }

}