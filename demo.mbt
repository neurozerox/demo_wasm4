// DECLARACIONES
///|
priv struct Player {
  mut x : Int
  mut y : Int
}

///|
priv struct Enemy {
  mut x : Int
  mut y : Int
  mut dir_x : Int
  mut dir_y : Int
}

///|
priv struct GameState {
  mut x : Int
  mut y : Int
}

///|
priv struct Stats {
  mut puntaje : Int
  mut velocidad : Int
  mut timer : Int
}

///|
priv struct RandomSeed {
  mut seed : Int
  mut frame_counter : Int
}

///|
priv struct GameStateFlags { // Para manejar el estado de la partida
  mut is_playing : Bool
}

///|
priv struct Sprite {
  data : FixedArray[Byte] // MoonBit usa 'Bytes' para arrays de datos crudos (como b"...")
  width : Int
  height : Int
}

///|
let screen_max = 160

///|
let jugador : Player = { x: 0, y: 0 }

///|
let enemigo : Enemy = { x: 150, y: 70, dir_x: -1, dir_y: 1 }

///|
let moneda : GameState = { x: 100, y: 50 }

///|
let initial_time : Int = 60 * 30

///|
let estado : Stats = { puntaje: 0, velocidad: 1, timer: initial_time }

///|
let rand_state : RandomSeed = { seed: 123, frame_counter: 0 } // Inicializa la semilla

///|
let game_flags : GameStateFlags = { is_playing: true }
// EN TUS DECLARACIONES GLOBALES

///|
let bgm_volume : UInt = 5

///|
let bgm_duration : UInt = 3

///|
let bgm_pulse_freq : UInt = 150

///|
let bgm_pulse_cycle : Int = 100

///|
fn make_tone_flag(channel_value : @wasm4.ToneChannel) -> @wasm4.ToneFlag {
  // Retorna un ToneFlag donde el canal es el valor que pasamos.
  @wasm4.ToneFlag::new(channel=channel_value) // La única sintaxis de constructor conocida
}

// FUNCIONES
// Generador Pseudoaleatorio Simple (LCG)

///|
fn next_random(seed : Int) -> Int {
  // LCG clásico (Numerical Recipes): avanza el estado COMPLETO de 32 bits.
  // Se deja desbordar a propósito (eso ES el módulo 2^32 del algoritmo).
  // Mantener el estado completo evita que el generador degenere; la
  // reducción al rango de pantalla se hace aparte (get_safe_random_coord).
  seed * 1664525 + 1013904223
}

// Generador de posición segura, que respeta el tamaño del sprite

///|
fn get_safe_random_coord(seed : Int, sprite_size : Int) -> Int {
  let max_coord = screen_max - sprite_size
  // El estado del LCG ya viene avanzado por el llamador; aquí solo lo
  // reducimos a [0, max_coord]. El % de un Int negativo (por el overflow
  // del LCG) puede dar negativo, así que tomamos el valor absoluto.
  let r = seed % (max_coord + 1)
  if r < 0 {
    -r
  } else {
    r
  }
}

//Reiniciar juego

///|
fn reset_game() -> Unit {
  // Reinicia todas las variables mutables a sus valores iniciales
  jugador.x = 0
  jugador.y = 0

  enemigo.x = 150
  enemigo.y = 70
  enemigo.dir_x = -1
  enemigo.dir_y = 1

  // Vuelve a colocar la moneda en su posición inicial
  moneda.x = 100
  moneda.y = 50

  estado.puntaje = 0
  estado.velocidad = 1
  estado.timer = initial_time // Reinicia el temporizador (faltaba)

  // Y lo más importante: ¡Activa el juego de nuevo!
  game_flags.is_playing = true
}

// --- DEFINICIÓN DE SPRITES (BITMAPS) ---

///|
let player_sprite : Sprite = {
  data: [
    0xff, 0xff, 0xff, 0xff, 0x80, 0x00, 0x00, 0x01, 0x80, 0x00, 0x00, 0x01, 0x80,
    0x00, 0x00, 0x01, 0x80, 0x00, 0x00, 0x01, 0x80, 0x00, 0x00, 0x01, 0x80, 0x00,
    0x00, 0x01, 0x80, 0x00, 0x00, 0x01, 0x80, 0x00, 0x00, 0x01, 0x80, 0x00, 0x00,
    0x01, 0x80, 0x00, 0x00, 0x01, 0x80, 0x00, 0x00, 0x01, 0xff, 0xff, 0xff, 0xff,
  ], // 64 bytes total
  width: 16,
  height: 16,
}

///|
let enemy_sprite : Sprite = {
  data: [0x81, 0x42, 0x24, 0x18, 0x18, 0x24, 0x42, 0x81], // 16 bytes total
  width: 8,
  height: 8,
}

///|
let coin_sprite : Sprite = {
  data: [0xc3, 0x99, 0x85, 0x85, 0x85, 0x85, 0x81, 0xc3],
  width: 8,
  height: 8,
}

// CUERPO

///|
pub fn start() -> Unit {
  // ESTABLECER LA PALETA DE COLORES
  //@wasm4.set_palette(1, @wasm4.rgb(0xFFFFFF)) // Color 1: Contorno/Blanco
  //@wasm4.set_palette(2, @wasm4.rgb(0x00FF00)) // Color 2: Jugador (Verde)
  //@wasm4.set_palette(3, @wasm4.rgb(0xFFFF00)) // Color 3: Moneda (Amarillo)
  //@wasm4.set_palette(4, @wasm4.rgb(0xFF0000)) // Color 4: Enemigo (Rojo)
  // LLAMADA SOSTENIDA DE MÚSICA DE FONDO (Si el binding lo permite)
  // WASM-4 generalmente reproduce música de fondo haciendo una llamada larga y cíclica aquí.
  //@wasm4.tone(
  //    (bgm_pulse_freq, bgm_pulse_freq),
  //    @wasm4.ADSR::new(0xFFFF), // Duración muy larga (casi infinita)
  //    @wasm4.ADSRVolume::new(50), 
  //    @wasm4.ToneFlag::new()
  //);
}

///|
pub fn update() -> Unit {
  let player_w = 16 // Ancho del jugador
  let player_h = 16 // Alto del jugador
  let coin_w = 8 // Ancho de moneda
  let coin_h = 8 // Alto de moneda
  let gamepad = @wasm4.get_gamepad(index=1)
  let enemy_w = 8 // <-- ¡CAMBIA A 8! (para coincidir con el sprite 8x8)
  let enemy_h = 8 // <-- ¡CAMBIA A 8! 
  let time_bonus_seconds = 5 // Segundos de bono
  let time_bonus_frames = time_bonus_seconds * 60 // 300 frames

  if game_flags.is_playing {
    // Avanza el contador de frames cada tick mientras se juega,
    // así el pulso del BGM se dispara cada bgm_pulse_cycle frames.
    rand_state.frame_counter += 1

    // ----------------------------------------------------
    // LÓGICA DE MÚSICA DE FONDO (BGM - Pulso Único Constante)
    // Se activa cada bgm_pulse_cycle frames
    if rand_state.frame_counter % bgm_pulse_cycle == 0 {
      // Usamos el CANAL DE RUIDO (3) para el BGM
      @wasm4.tone(
        (bgm_pulse_freq, bgm_pulse_freq),
        @wasm4.ADSR::new(bgm_duration),
        @wasm4.ADSRVolume::new(bgm_volume),
        make_tone_flag(@wasm4.ToneChannel::Noise), // <-- Usar el valor 3 (Ruido)
      )
    }
    // ----------------------------------------------------

    // Limpia el fondo al inicio de cada frame para evitar estelas de sprites
    @wasm4.set_draw_colors(0x01)
    @wasm4.rect(0, 0, screen_max, screen_max)

    // 1. MOVIMIENTO HORIZONTAL Y REBOTE (SUAVE)
    let current_player_speed = estado.velocidad
    let enemy_horizontal_speed = current_player_speed + 1

    // Aplica el movimiento: (posición += dirección * velocidad)
    enemigo.x += enemigo.dir_x * enemy_horizontal_speed

    // Lógica de REBOTE HORIZONTAL
    if enemigo.x + enemy_w >= screen_max {
      enemigo.dir_x = -1 // Toca el borde derecho, ahora va a la IZQUIERDA
      // DESVÍO VERTICAL LEVE: Inyecta un pequeño cambio aleatorio en Y.
      // Generamos un número (ej. 0 a 7) y lo sumamos a Y.
      rand_state.seed = next_random(rand_state.seed) // Avanza el LCG completo
      let offset = rand_state.seed % 8
      enemigo.y += if offset < 0 { -offset } else { offset }
    } else if enemigo.x <= 0 {
      enemigo.dir_x = 1 // Toca el borde izquierdo, ahora va a la DERECHA
      // DESVÍO VERTICAL LEVE: Inyecta un pequeño cambio aleatorio en Y.
      rand_state.seed = next_random(rand_state.seed) // Avanza el LCG completo
      let offset = rand_state.seed % 8
      enemigo.y += if offset < 0 { -offset } else { offset }
    }

    // 2. MOVIMIENTO VERTICAL (ZIG-ZAG) Y REBOTE PURO
    let enemy_speed_y = 1
    enemigo.y += enemigo.dir_y * enemy_speed_y // Aplica el zig-zag

    // Lógica de REBOTE VERTICAL CON RUIDO ALEATORIO
    if enemigo.y + enemy_h >= screen_max {
      enemigo.dir_y = -1 // Toca el fondo, ahora va ARRIBA
    } else if enemigo.y <= 0 {
      enemigo.dir_y = 1 // Toca el techo, ahora va ABAJO
    }

    // lógica de movimiento del jugador
    // Ejes independientes: permite moverse en diagonal (derecha+abajo, etc.)
    if gamepad.button_right {
      jugador.x += estado.velocidad
    }
    if gamepad.button_left {
      jugador.x -= estado.velocidad
    }
    if gamepad.button_down {
      jugador.y += estado.velocidad
    }
    if gamepad.button_up {
      jugador.y -= estado.velocidad
    }

    // Clamp: mantiene al jugador dentro de la pantalla en ambos ejes
    // (evita salir por la izquierda/arriba con velocidad > 1)
    if jugador.x < 0 {
      jugador.x = 0
    }
    if jugador.x + player_w > screen_max {
      jugador.x = screen_max - player_w
    }
    if jugador.y < 0 {
      jugador.y = 0
    }
    if jugador.y + player_h > screen_max {
      jugador.y = screen_max - player_h
    }

    // Lógica de colisión monedas
    if jugador.x < moneda.x + coin_w &&
      jugador.x + player_w > moneda.x &&
      jugador.y < moneda.y + coin_h &&
      jugador.y + player_h > moneda.y {

      // Tono 1 (Bajo) - Rápido, ascendente
      @wasm4.tone(
        (440, 550), // 1. Frecuencia (Tupla)
        @wasm4.ADSR::new(5), // 2. Duración (ADSR)
        @wasm4.ADSRVolume::new(100), // 3. Volumen (ADSRVolume)
        @wasm4.ToneFlag::new(), // 4. Flags (Constructor sin argumentos)
      )

      // Tono 2 (Alto)
      @wasm4.tone(
        (880, 880),
        @wasm4.ADSR::new(5),
        @wasm4.ADSRVolume::new(100),
        @wasm4.ToneFlag::new(),
      )

      //ejemplo sacado de github
      // @wasm4.tone((200,401),@wasm4.ADSR::new(10),@wasm4.ADSRVolume::new(100),@wasm4.ToneFlag::new(channel=Noise,mode=Duty_1_2,pan=Center));

      estado.velocidad += 1
      estado.puntaje += 1
      estado.timer += time_bonus_frames

      rand_state.seed = next_random(rand_state.seed)
      moneda.x = get_safe_random_coord(rand_state.seed, coin_w)
      rand_state.seed = next_random(rand_state.seed)
      moneda.y = get_safe_random_coord(rand_state.seed, coin_h)
    }

    // --- LÓGICA DE COLISIÓN CON ENEMIGO (Game Over) ---
    if jugador.x < enemigo.x + enemy_w &&
      jugador.x + player_w > enemigo.x &&
      jugador.y < enemigo.y + enemy_h &&
      jugador.y + player_h > enemigo.y {
      @wasm4.tone(
        (100, 50),
        @wasm4.ADSR::new(30),
        @wasm4.ADSRVolume::new(100),
        @wasm4.ToneFlag::new(),
      )
      game_flags.is_playing = false // ¡Game Over!
    }

    // --- LÓGICA DEL TEMPORIZADOR ---
    estado.timer -= 1 // Resta 1 frame en cada tick

    // Condición de Game Over por tiempo
    if estado.timer <= 0 {
      game_flags.is_playing = false // Forzar Game Over
    }

    // --- LÓGICA DE URGENCIA (ÚLTIMOS 5 SEGUNDOS) ---
    if estado.timer < 300 { // 5 segundos * 60 FPS = 300 frames
      // Si el número de frame es par (ej. timer % 10 < 5), dibuja un color de pánico.
      if estado.timer % 10 < 5 {
        // Dibuja el fondo con un color de paleta diferente (ej. Color 4, que es Rojo)
        @wasm4.set_draw_colors(0x04)
        @wasm4.rect(0, 0, screen_max, screen_max) // Pinta toda la pantalla
      } else {
        // Dibuja el fondo blanco/verde claro que usas
        @wasm4.set_draw_colors(0x00) // Color 0 de la paleta (que es tu fondo)
        @wasm4.rect(0, 0, screen_max, screen_max)
      }
    }

    //TEXTO PUNTAJE
    let score_text = "SCORE: " + estado.puntaje.to_string()
    @wasm4.set_draw_colors(4)
    @wasm4.text(score_text, 4, 5)

    // DIBUJO DEL TIEMPO (Conversión a segundos)
    let seconds_left = estado.timer / 60
    let timer_text = "TIME: " + seconds_left.to_string()

    // Muestra el tiempo en pantalla (ej. esquina superior derecha)
    @wasm4.set_draw_colors(4)
    @wasm4.text(timer_text, 90, 5) // Coordenada ajustada

    // --- DIBUJO CON BLIT ---
    let blit_flag_none : @wasm4.BlitFlag = {
      one_bit_per_pixel: true, // Asumiendo que es false por defecto
      flip_x: false,
      flip_y: false,
      rotate: false,
    }

    // 1. Dibuja el JUGADOR
    @wasm4.set_draw_colors(0x02 | (0x00 << 2))
    let player_obj = @wasm4.sprite(player_sprite.data)
    player_obj.blit(
      jugador.x,
      jugador.y,
      player_sprite.width,
      player_sprite.height,
      blit_flag_none,
    )

    // 2. Dibuja el ENEMIGO
    @wasm4.set_draw_colors(0x04 | (0x00 << 2))
    let enemy_obj = @wasm4.sprite(enemy_sprite.data)
    enemy_obj.blit(
      enemigo.x,
      enemigo.y,
      enemy_sprite.width,
      enemy_sprite.height,
      blit_flag_none,
    )

    // 3. Dibuja la MONEDA
    @wasm4.set_draw_colors(0x03 | (0x00 << 2))
    let coin_obj = @wasm4.sprite(coin_sprite.data)
    coin_obj.blit(
      moneda.x,
      moneda.y,
      coin_sprite.width,
      coin_sprite.height,
      blit_flag_none,
    )
  } else {
    // Limpia el fondo de la pantalla de game over
    @wasm4.set_draw_colors(0x01)
    @wasm4.rect(0, 0, screen_max, screen_max)

    // PANTALLA DE GAME OVER
    @wasm4.set_draw_colors(4)
    @wasm4.text("GAME OVER!", 40, 70)
    @wasm4.set_draw_colors(3)
    let final_score = "Puntaje: " + estado.puntaje.to_string()
    @wasm4.text(final_score, 38, 90)

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
