# Lembretes
# - 
# TO-DO List
# - Calcular quanto espaço cada inimigo usa.
# - Com isso, definir espaço máximo a ser alocado para os inimigos em cada fase.
# - Atualizar Bot_x e Bot_y (usar Top_x e Top_y como base)
# - Otimizar algumas funções usando uma booleana para impedir que executem quando não houve movimento


# Constantes globais
.eqv INPUT_DATA_ADDR   0xFF200004	# Endereço onde é armazenado caracteres de entrada
.eqv INPUT_RDY_ADDR    0xFF200000	# Endereço com a informação sobre o estado do buffer de input. 1: pronto, 0: vazio
.eqv INPUT_FINISH      0x030		# Caractere de finalização	

.eqv TIME_STEP         0x030		# Intervalo entre atualizações, em milissegundos
.eqv DISPLAY_ADDR      0xFF000000	# Endereço do display
.eqv DIGDUG_BS_SPEED   0x0A		# Velocidade de Dig Dug (No momento, precisa ser menor que 10, senão quebra o jogo
# Controles
.eqv GAME_UP_KEY       0x077		# w
.eqv GAME_DW_KEY       0x073		# s	
.eqv GAME_LF_KEY       0x061		# a
.eqv GAME_RT_KEY       0x064		# d
.eqv GAME_ATK_KEY      0x06C		# l

# Informação de buffer do jogo
.eqv POOKA_SIZE        59		# Espaço em bytes ocupado por um Pooka - Sempre lembrar de atualizar após alterações
.eqv POOKA_POS_OFFSET  29   
.eqv FYGAR_SIZE        0
.eqv ROCK_SIZE         0

# Limites

.eqv WORLD_UP_EDGE_X   3000		# Limites do mundo do jogo
.eqv WORLD_UP_EDGE_Y   2200
.eqv WORLD_LW_EDGE_X   0
.eqv WORLD_LW_EDGE_Y   200

.data

# Estado do jogo
GAME_SCORE: 	.word 0x00000000
GAME_HISCORE: 	.word 0x00000000
GAME_STAGE: 	.byte 0
GAME_LIVES:	.byte 5


#################################
# Dados do Dig Dug (personagem) #
#################################

DIGDUG_DIRECTION: 	.word 0x00	# 0: cima; 1: baixo; 2: esquerda; 3: direita
DIGDUG_DIGGING: 	.byte 0x01
DIGDUG_MOVED:		.byte 0x00
DIGDUG_CYCLE:		.word 0x00

# Coordenadas dos limites da box.
DIGDUG_TOP_X: .word 0
DIGDUG_TOP_Y: .word 0
DIGDUG_BOT_X: .word 0
DIGDUG_BOT_Y: .word 0

# Velocidade, em pixels. Pode ter valores negativos.
DIGDUG_SPEED_X: .word 0
DIGDUG_SPEED_Y: .word 0

DIGDUG_TOP_X_P: .word 0
DIGDUG_TOP_Y_P: .word 0
DIGDUG_BOT_X_P: .word 0
DIGDUG_BOT_Y_P: .word 0

# Cores de fundo da posição atual do personagem, para redesenho
DIGDUG_BG_DATA: .space 400

#
DIGDUG_LF_DIG: .word 0
DIGDUG_RT_DIG: .word 0
DIGDUG_UP_DIG: .word 0
DIGDUG_DW_DIG: .word 0


############
# Inimigos #
############

# Pooka

POOKA_IN: 		.byte 1
POOKA_DIRECTION: 	.word 0x00
POOKA_CYCLE: 		.word 0x00
POOKA_GHOST:		.byte 0x00
POOKA_INFLATE:		.word 0x00
POOKA_CRUSHED:		.byte 0x00
POOKA_ROCK:		.word 0x00

POOKA_SPEED_X: 		.word 0
POOKA_SPEED_Y: 		.word 0

POOKA_TOP_X: 		.word 255
POOKA_TOP_Y: 		.word 255
POOKA_BOT_X: 		.word 255
POOKA_BOT_Y: 		.word 255

POOKA_TOP_X_P: 		.word 255
POOKA_TOP_Y_P: 		.word 255
POOKA_BOT_X_P: 		.word 255
POOKA_BOT_Y_P: 		.word 255

# Fygar

FYGAR_IN: .byte 1

FYGAR_SPEED_X: .word 2
FYGAR_SPEED_Y: .word 2

FYGAR_TOP_X: .word 255
FYGAR_TOP_Y: .word 255
FYGAR_BOT_X: .word 255
FYGAR_BOT_Y: .word 255


# Dados de imagem
SPRITE_SHEET_PATH: 	.asciz "bin/digdug_sprtsheet.bin"
SPRITE_SHEET_BUFFER: 	.space 42504
DIGDUG_SPRT_SHEET_PATH: .asciz "bin/digdug_sprites.bin"
DIGDUG_SPRT_SHEET:	.space 18000

BACKGROUND_PATH: 	.asciz "bin/digdug_bg_01.bin"
BACKGROUND_H_PATH:	.asciz "bin/digdug_bg_horizontal.bin"
BACKGROUND_V_PATH:	.asciz "bin/digdug_bg_vertical.bin"
BACKGROUND_BUFFER:      .space 76800
BACKGROUND_H_BUFFER:	.space 76800
BACKGROUND_V_BUFFER:	.space 76800
TUNNEL_M_PATH:		.asciz "bin/tunnel_mask.bin"
TUNNEL_MASK:		.space 400

# Representação virtual dos túneis

GAME_MAP: 		.space 76800
GAP_DATA:		.space 324
GAP_DATA_PATH:		.asciz "bin/gap.bin"
LEVEL_1_PATH: 		.asciz "bin/digdug_level_01.bin"
LEVEL_2_PATH: 		.asciz "placeholder"
LEVEL_3_PATH: 		.asciz "placeholder"
LEVEL_4_PATH: 		.asciz "placeholder"
LEVEL_5_PATH: 		.asciz "placeholder"


# Buffer de objetos

ALIGNMENT_BUFFER_00:	.space 1
# Pooka(s) - Espaço para só um, por enquanto
GAME_POOKA_COUNT:	.byte 0 		# Quantidade de pookas remanescentes
GAME_POOKA_BUFFER: 	.space 59

.text

# Funções

# Carrega um inimigo no jogo
# No futuro, fazer isso um load enemy genérico
# %template: label; %size: eqv; %enemy_buffer: label; %posoffset: eqv; %posx e %posy: registradores
.macro LOAD_ENEMY (%template, %size, %enemy_buffer, %posoffset, %posx, %posy)
	la t0, %enemy_buffer
	# Adicionamos 1 para o contador de inimigos
	lb t1, -1(t0)
	addi t1, t1, 1
	sb t1, -1(t0)
	
	# O teste presume que sempre haverá um espaço vazio, só precisa encontrá-lo
	TEST_AVAILABILITY:
		lb t1, (t0)
		beq t1, zero, TEST_AVAILABILITY_END
		addi t0, t0, %size
		j TEST_AVAILABILITY
	TEST_AVAILABILITY_END:
	
	# Copia o template para o espaço
	
	la t1, %template
	li t2, %size
	mv t4, t0					# Armazena o endereço do começo do espaço para depois
	
	LOAD_ENEMY_TO_BUFFER:
		beq t2, zero, LOAD_ENEMY_END
		lb t3, (t1)
		sb t3, (t0)
		addi t0, t0, 1
		addi t1, t1, 1
		addi t2, t2, -1
		j LOAD_ENEMY_TO_BUFFER
	LOAD_ENEMY_END:
	
	# Definir posição inicial
	
	li t3, %posoffset
	add t0, t4, t3
	mv t1, %posx
	mv t2, %posy
	
	sw t1, (t0)
	sw t2, 4(t0)
	
	addi t1, t1, 200
	addi t2, t2, 200
	addi t0, t0, 8
	
	sw t1, (t0)
	sw t2, 4(t0)
	
.end_macro


# Acha o tempo atual e armazena o valor no registrador %reg
.macro GET_TIME (%reg)
	li a7, 30
	ecall
	mv %reg, a0
.end_macro

# Pausa o programa pelo tempo no registrador %reg, em milissegundos
.macro WAIT (%reg)
	mv a0, %reg
	bgez a0, NORMAL_TIME_STEP	# Caso o loop demore demais, não esperamos nada
	li a0, 0		
NORMAL_TIME_STEP:
	li a7, 32
	ecall
.end_macro

# Abre, carrega um arquivo em memória, na label dada, fecha o arquivo. É preciso ter certeza que o espaço necessário já foi reservado
.macro LOAD_FILE (%file_l, %label, %size)
	la a0, %file_l			# Abrimos o arquivo usando o caminho armazenado na label
	li a1, 0
	li a7, 1024
	ecall				# Descriptor é colocado em a0, que iremos utilizar a seguir
	mv t0, a0			# Descriptor é armazenado t0, senão será perdido na próxima chamada
	
	la a1, %label			# Endereço onde os dados serão armazenados
	li a2, %size			# Tamanho a armazenar
	li a7, 63
	ecall
	
	mv a0, t0			# Fechamos o arquivo
	li a7, 57
	ecall
.end_macro

# Dividimos a função de desenho em "Desenhar" e "Desenhar com transparência" porque o uso de transparência é mais custoso
# e nem sempre precisamos dela

# Desenha uma imagem armazenada em memória na tela, na posição especificada
# largura do segmento PRECISA ser múltipla de 4
# %address: endereço da imagem; %offset: onde começar a ler; %width: largura da imagem; %cropw: largura do segmento; %croph: altura do segmento
# %posx: coordenada X da tela; %posy: coordenada Y da tela
.macro DRAW_IMG (%address, %width, %offset, %cropw, %croph, %posx, %posy)
	la t0, %address					# Adicionamos ao endereço de início o offset desejado
	mv t1, %offset
	add t0, t0, t1
	
	# Calculamos qual endereço onde começar a desenhar
	mv t3, %posy					# Primeiro pegamos a coordenada Y
	li t1, 320					# Multiplicamos pela largura do display para chegarmos na linha certa
	mul t3, t3, t1			
	add t3, t3, %posx				# Adiciona-se o valor da cordenada X, para chegar na coluna certa
	li t1, DISPLAY_ADDR				# A tudo isso, adicionamos o endereço onde começa o buffer de display
	add t3, t3, t1
	
	mv t2, %croph
	# t0: endereço da imagem na memória
	# t1: número de intervalos de 4 pixels, por linha, a desenhar
	# t2: número de linhas a desenhar
	# t3: endereço do buffer de display a desenhar
START_DRAW:
	beq t2, zero, END_DRAW				# Se o número de linhas a desenhar for zero, o loop acaba
	mv t1, %cropw
	srli t1, t1, 1
	DRAW_PIXEL:			
		beq t1, zero, END_DRAW_PIXEL		# Se o número de pixels na linha a desenhar for zero, saímos do loop interior
		
		lb t4, (t0)				# Armazena a cor em t4 temporariamente
		sb t4, (t3)				

		addi t0, t0, 1				# Passa para o próximo pixel
		addi t3, t3, 1
		
		lb t4, (t0)
		sb t4, (t3)
		
		addi t0, t0, 1				# Passa para o próximo pixel
		addi t3, t3, 1
		
		addi t1, t1, -1				# Um intervalo a menos a desenhar
		j DRAW_PIXEL
	END_DRAW_PIXEL:
	# Terminamos de desenhar a linha, passamos para a próxima

	mv t5, %cropw					# Offset na imagem: (largura do arquivo) - (largura do segmento)
	addi t0, t0, %width
	sub t0, t0, t5
	addi t3, t3, 320				# Offset no buffer: (largura do display) - (largura do segmento)
	sub t3, t3, t5
	
	addi t2, t2, -1 				# Uma linha a menos a desenhar
	j START_DRAW
END_DRAW:
	
.end_macro

# Similar ao DRAW_IMG, mas para a representação invisível do mapa de jogo.
# %address: endereço de leitura; %offset: onde começar a ler; %width: largura da imagem; %cropw: largura do segmento; %croph: altura do segmento
# %posx: coordenada X da tela; %posy: coordenada Y da tela
.macro WRITE_TO_BUFFER (%address, %width, %offset, %cropw, %croph, %posx, %posy, %map_addr)
	la t0, %address					# Adicionamos ao endereço de início o offset desejado
	mv t1, %offset
	add t0, t0, t1
	
	# Calculamos qual endereço onde começar a desenhar
	mv t3, %posy					# Primeiro pegamos a coordenada Y
	li t1, 320					# Multiplicamos pela largura do display para chegarmos na linha certa
	mul t3, t3, t1			
	add t3, t3, %posx				# Adiciona-se o valor da cordenada X, para chegar na coluna certa
	mv t1, %map_addr				# A tudo isso, adicionamos o endereço onde começa o buffer de display
	add t3, t3, t1
	
	mv t2, %croph
	# t0: endereço da imagem na memória
	# t1: número de pixels por linha a desenhar
	# t2: número de linhas a desenhar
	# t3: endereço do buffer de display a desenhar
	# Agora, leremos cada pixel individualmente, com a ajuda de dois loops, um interior ao outro
START_DRAW:
	beq t2, zero, END_DRAW				# Se o número de linhas a desenhar for zero, o loop acaba
	mv t1, %cropw
	DRAW_PIXEL:			
		beq t1, zero, END_DRAW_PIXEL		# Se o número de pixels na linha a desenhar for zero, saímos do loop interior
		lb t4, (t0)				# Armazena a cor em t4 temporariamente
		sb t4, (t3)				# Desenhamos o pixel no buffer de display
		addi t0, t0, 1				# Passa para o próximo pixel
		addi t3, t3, 1
		addi t1, t1, -1				# Um pixel a menos a desenhar
		j DRAW_PIXEL
	END_DRAW_PIXEL:
	# Terminamos de desenhar a linha, passamos para a próxima

	mv t5, %cropw					# Offset na imagem: (largura do arquivo) - (largura do segmento)
	addi t0, t0, %width
	sub t0, t0, t5
	addi t3, t3, 320				# Offset no buffer: (largura do display) - (largura do segmento)
	sub t3, t3, t5
	
	addi t2, t2, -1					# Uma linha a menos a desenhar
	j START_DRAW
END_DRAW:
.end_macro

.macro DRAW_IMG_TR (%address, %width, %offset, %cropw, %croph, %posx, %posy)
	la t0, %address					# Adicionamos ao endereço de início o offset desejado
	mv t1, %offset
	add t0, t0, t1
	
	# Calculamos qual endereço onde começar a desenhar
	mv t3, %posy					# Primeiro pegamos a coordenada Y
	li t1, 320					# Multiplicamos pela largura do display para chegarmos na linha certa
	mul t3, t3, t1			
	add t3, t3, %posx				# Adiciona-se o valor da cordenada X, para chegar na coluna certa
	li t1, DISPLAY_ADDR				# A tudo isso, adicionamos o endereço onde começa o buffer de display
	add t3, t3, t1
	
	mv t2, %croph
	# t0: endereço da imagem na memória
	# t1: número de pixels por linha a desenhar
	# t2: número de linhas a desenhar
	# t3: endereço do buffer de display a desenhar
	# Agora, leremos cada pixel individualmente, com a ajuda de dois loops, um interior ao outro
START_DRAW:
	beq t2, zero, END_DRAW				# Se o número de linhas a desenhar for zero, o loop acaba
	mv t1, %cropw
	DRAW_PIXEL:			
		beq t1, zero, END_DRAW_PIXEL		# Se o número de pixels na linha a desenhar for zero, saímos do loop interior
		lb t4, (t0)				# Armazena a cor em t4 temporariamente
		beq t4, zero, TEST_TRANSP		# Se a cor do pixel for preta, não desenhamos
		sb t4, (t3)				# Desenhamos o pixel no buffer de display
	TEST_TRANSP:
		addi t0, t0, 1				# Passa para o próximo pixel
		addi t3, t3, 1
		addi t1, t1, -1				# Um pixel a menos a desenhar
		j DRAW_PIXEL
	END_DRAW_PIXEL:
	# Terminamos de desenhar a linha, passamos para a próxima

	mv t5, %cropw					# Offset na imagem: (largura do arquivo) - (largura do segmento)
	addi t0, t0, %width
	sub t0, t0, t5
	addi t3, t3, 320				# Offset no buffer: (largura do display) - (largura do segmento)
	sub t3, t3, t5
	
	addi t2, t2, -1					# Uma linha a menos a desenhar
	j START_DRAW
END_DRAW:
.end_macro


# Muda o valor de uma label - Sempre estar ciente do valor máximo que pode armazenar
.macro SET_VALUE_IMM (%label, %value)
	la t0, %label		# Armazena endereço da label em t0
	li t1, %value		# Armazena valor em t1
	sw t1, 0(t0)		# Muda o valor no endereço t5 para o valor t6
.end_macro

# Muda o valor de uma label, usando um registrador - Sempre estar ciente do valor máximo que pode armazenar
# Não usar registrador t0 como parâmetro dessa função
.macro SET_VALUE_REG (%label, %reg)
	la t0, %label		# Armazena endereço da label em t0
	mv t1, %reg		# Armazena valor em t1
	sw t1, 0(t0)		# Muda o valor no endereço t5 para o valor t6
.end_macro


######################################
######################################
#	 Começo do programa	     #
######################################
######################################
	
	# To-do: Decidir quais arquivos só precisam ser carregados uma vez de fato
	
	# Carrega os arquivos de imagem
	LOAD_FILE(BACKGROUND_PATH, BACKGROUND_BUFFER, 76800)

	LOAD_FILE(BACKGROUND_H_PATH, BACKGROUND_H_BUFFER, 76800)
	LOAD_FILE(BACKGROUND_V_PATH, BACKGROUND_V_BUFFER, 76800)

	LOAD_FILE(SPRITE_SHEET_PATH, SPRITE_SHEET_BUFFER, 42504)
	LOAD_FILE(DIGDUG_SPRT_SHEET_PATH, DIGDUG_SPRT_SHEET, 18000)
	# Imagem de lacuna na representação invisível
	LOAD_FILE(GAP_DATA_PATH, GAP_DATA, 324)
	# Imagem de lacuna na representação gráfica
	LOAD_FILE(TUNNEL_M_PATH, TUNNEL_MASK, 400)

	
	# Setup de level
	# Carrega mapa de jogo
	LOAD_FILE(LEVEL_1_PATH, GAME_MAP, 76800)
	
	li a0, 200
	li a1, 800
	LOAD_ENEMY(POOKA_IN, POOKA_SIZE, GAME_POOKA_BUFFER, POOKA_POS_OFFSET, a0, a1)
	
	li a0, 320
	li a1, 240
	DRAW_IMG(BACKGROUND_BUFFER, 320, zero, a0, a1, zero, zero)
	
	

	li s6, 1 # Bool para MOVEMENT TEST - Remover depois
	
MAIN: 
	lw t0, INPUT_RDY_ADDR		# Vemos se há caractere a ler
	beq t0, zero, GET_CURRENT_TIME  
	lw t0, INPUT_DATA_ADDR   	# Termina o loop se recebermos o caractere desejado
	li t1, INPUT_FINISH		# Caractere desejado
	beq t0, t1, END			# Teste
	mv s2, t0			# Colocamos o caractere em buffer para uso futuro
	
GET_CURRENT_TIME:
	GET_TIME(s0) 			# Pegamos o tempo no começo do loop
	
	# Pular para endereço da sessão do jogo relevante
	# Sessões: Tela inicial, Controles, Animação inicial, Fase
	
	
	# Formato da animação inicial
	# Direção > Coordernada de mudança > Nova direção

###
MOVEMENT_TEST_SETUP: beq s6, zero, MOVEMENT_TEST_SETUP_DONE
	# Posição inicial
	# Escala da representação virtual de espaço para pixels é 10:1
	
	SET_VALUE_IMM(DIGDUG_TOP_X, 1400)
	SET_VALUE_IMM(DIGDUG_TOP_Y, 1200)
	SET_VALUE_IMM(DIGDUG_BOT_X, 1590)
	SET_VALUE_IMM(DIGDUG_BOT_Y, 1390)
	
	lw t0, DIGDUG_TOP_X
	li t6, 10
	div t0, t0, t6
	
	lw t1, DIGDUG_TOP_Y
	div t1, t1, t6
	
	li t3, 320
	mul t1, t1, t3
	add t0, t1, t0
	la t5, BACKGROUND_BUFFER
	add t0, t0, t5
	la t2, DIGDUG_BG_DATA
	li t3, 20
	li t5, 20
	
	SAVE_BG_DATA_FIRST_OUTER:
		beq t5, zero, SAVE_BG_DATA_FIRST_DONE
		li t3, 20
		SAVE_BG_DATA_FIRST_INNER:
			beq t3, zero, SAVE_BG_DATA_FIRST_INNER_DONE
			# 4 por vez
			lb t4, (t0)
			sb t4, (t2)
			addi t0, t0, 1
			addi t2, t2, 1
	
			addi t3, t3, -1
			j SAVE_BG_DATA_FIRST_INNER
		SAVE_BG_DATA_FIRST_INNER_DONE:
		addi t0, t0, 300
		addi t5, t5, -1
		j SAVE_BG_DATA_FIRST_OUTER
	SAVE_BG_DATA_FIRST_DONE:
	
	li s6, 0
MOVEMENT_TEST_SETUP_DONE:


MOVEMENT_PHASE:


	DIGDUG_MOVE:
	# Pegamos o input recebido, que está armazenado em s2, testamos para ver se é uma direção válida
	
	mv t0, s2
	li t1, GAME_UP_KEY
	beq t0, t1, DIGDUG_MOVE_UP
	li t1, GAME_LF_KEY
	beq t0, t1, DIGDUG_MOVE_LEFT
	li t1, GAME_DW_KEY
	beq t0, t1, DIGDUG_MOVE_DOWN
	li t1, GAME_RT_KEY
	beq t0, t1, DIGDUG_MOVE_RIGHT
	li t1, GAME_ATK_KEY
	beq t0, t1, DIGDUG_ATTACK
	j DIGDUG_CALC_NEXT_POS
	
	DIGDUG_MOVE_UP:
		# Mudamos a velocidade de Dig Dug - magnitude, direção e sentido
		# Checamos se é uma posição válida para mudança de direção - X e Y precisam ser múltiplos de 20
		# A checagem só é feita se houver mudança de direção
		lw t0, DIGDUG_DIRECTION
		li t1, 1
		ble t0, t1, DIGDUG_MOVE_UP_OK		# Se Dig Dug não mudar de direção, ignoramos o próximo teste
		lw t0, DIGDUG_TOP_X
		lw t1, DIGDUG_TOP_Y
		li t2, 200				# Testamos se a posição atual se alinha com a grade. Adiciona-se 200 para o caso de coordenada igual a zero
		li t3, 10				
		add t0, t0, t2
		add t1, t1, t2
		div t0, t0, t3				# Divide-se por dez para conseguir coordenada em relação ao display 320x240
		div t1, t1, t3
		li t2, 20
		rem t0, t0, t2				# Testamos se as coordenadas são múltiplas de 20
		rem t1, t1, t2
		bne t0, zero, DIGDUG_CALC_NEXT_POS
		bne t1, zero, DIGDUG_CALC_NEXT_POS
	DIGDUG_MOVE_UP_OK:
		li a0, 0xFFFFFFFF		# Move-se para cima. O componente Y da velocidade deve ser negativo, então convertemos
		li t0, DIGDUG_BS_SPEED
		sub a0, a0, t0
		addi a0, a0, 1
		SET_VALUE_REG(DIGDUG_SPEED_Y, a0)
		SET_VALUE_REG(DIGDUG_SPEED_X, zero)
		SET_VALUE_IMM(DIGDUG_DIRECTION, 0)
		j DIGDUG_CALC_NEXT_POS

	DIGDUG_MOVE_DOWN:
		lw t0, DIGDUG_DIRECTION
		li t1, 1
		ble t0, t1, DIGDUG_MOVE_DOWN_OK
		lw t0, DIGDUG_TOP_X
		lw t1, DIGDUG_TOP_Y
		li t2, 200
		li t3, 10
		add t0, t0, t2
		add t1, t1, t2
		div t0, t0, t3
		div t1, t1, t3
		li t2, 20
		rem t0, t0, t2
		rem t1, t1, t2
		bne t0, zero, DIGDUG_CALC_NEXT_POS
		bne t1, zero, DIGDUG_CALC_NEXT_POS	
	DIGDUG_MOVE_DOWN_OK:
		li a0, DIGDUG_BS_SPEED
		SET_VALUE_REG(DIGDUG_SPEED_Y, a0)
		SET_VALUE_REG(DIGDUG_SPEED_X, zero)
		SET_VALUE_IMM(DIGDUG_DIRECTION, 1)
		j DIGDUG_CALC_NEXT_POS

	DIGDUG_MOVE_LEFT:
		lw t0, DIGDUG_DIRECTION
		li t1, 2
		bge t0, t1, DIGDUG_MOVE_LEFT_OK
		lw t0, DIGDUG_TOP_X
		lw t1, DIGDUG_TOP_Y
		li t2, 200
		li t3, 10
		add t0, t0, t2
		add t1, t1, t2
		div t0, t0, t3
		div t1, t1, t3
		li t2, 20
		rem t0, t0, t2
		rem t1, t1, t2
		bne t0, zero, DIGDUG_CALC_NEXT_POS
		bne t1, zero, DIGDUG_CALC_NEXT_POS
	DIGDUG_MOVE_LEFT_OK:
		li a0, 0xFFFFFFFF		# Move-se para a esquerda. O componente X da velocidade deve ser negativo, então convertemos
		li t0, DIGDUG_BS_SPEED
		sub a0, a0, t0
		addi a0, a0, 1
		SET_VALUE_REG(DIGDUG_SPEED_X, a0)
		SET_VALUE_REG(DIGDUG_SPEED_Y, zero)
		SET_VALUE_IMM(DIGDUG_DIRECTION, 2)
		j DIGDUG_CALC_NEXT_POS
	
	DIGDUG_MOVE_RIGHT:
		lw t0, DIGDUG_DIRECTION
		li t1, 2
		bge t0, t1, DIGDUG_MOVE_RIGHT_OK
		lw t0, DIGDUG_TOP_X
		lw t1, DIGDUG_TOP_Y
		li t2, 200
		li t3, 10
		add t0, t0, t2
		add t1, t1, t2
		div t0, t0, t3
		div t1, t1, t3
		li t2, 20
		rem t0, t0, t2
		rem t1, t1, t2
		bne t0, zero, DIGDUG_CALC_NEXT_POS
		bne t1, zero, DIGDUG_CALC_NEXT_POS
	DIGDUG_MOVE_RIGHT_OK:
		li a0, DIGDUG_BS_SPEED
		SET_VALUE_REG(DIGDUG_SPEED_X, a0)
		SET_VALUE_REG(DIGDUG_SPEED_Y, zero)
		SET_VALUE_IMM(DIGDUG_DIRECTION, 3)
		j DIGDUG_CALC_NEXT_POS

	DIGDUG_ATTACK: # Solta a mangueira, fica parado enquanto espera voltar

	DIGDUG_CALC_NEXT_POS:
	
		# Guardamos a posição atual
		lw a0, DIGDUG_TOP_X
		SET_VALUE_REG(DIGDUG_TOP_X_P, a0)
		lw a0, DIGDUG_TOP_Y
		SET_VALUE_REG(DIGDUG_TOP_Y_P, a0)
		lw a0, DIGDUG_BOT_X
		SET_VALUE_REG(DIGDUG_BOT_X_P, a0)
		lw a0, DIGDUG_BOT_Y
		SET_VALUE_REG(DIGDUG_BOT_Y_P, a0)
	
		# Checa se Dig Dug não saiu da borda do jogo. Testamos X e Y.
		# Atualizamos X
		lw a0, DIGDUG_TOP_X
		lw t0, DIGDUG_SPEED_X
		add a0, a0, t0
		li t0, WORLD_UP_EDGE_X
		blt a0, t0, DIGDUG_TEST_LOWER_X
		mv a0, t0
		j DIGDUG_SET_NEW_X
	DIGDUG_TEST_LOWER_X:
		li t0, WORLD_LW_EDGE_X
		bge a0, t0, DIGDUG_SET_NEW_X
		mv a0, t0
	DIGDUG_SET_NEW_X:
		SET_VALUE_REG(DIGDUG_TOP_X, a0)
		# Atualizamos Y
		lw a0, DIGDUG_TOP_Y
		lw t0, DIGDUG_SPEED_Y
		add a0, a0, t0

		li t0, WORLD_UP_EDGE_Y
		blt a0, t0, DIGDUG_TEST_LOWER_Y
		mv a0, t0
		j DIGDUG_SET_NEW_Y
	DIGDUG_TEST_LOWER_Y:
		li t0, WORLD_LW_EDGE_Y
		bge a0, t0, DIGDUG_SET_NEW_Y
		mv a0, t0
	DIGDUG_SET_NEW_Y:
		SET_VALUE_REG(DIGDUG_TOP_Y, a0)
	
	DIGDUG_CALC_NEXT_POS_END:
	
		# Colocar checagem se está cavando ou não
		# Para isso, testar TOP e BOT
		
	# Pooka
	# Ao contrário de Dig Dug, Pooka colide com paredes
	# Tem a mesma restrição de movimento na grade
	
	
	
	
	
UPDATE_GAME_MAP:


		# Checamos se Dig Dug cavou algo e atualizamos o mapa
		# Como a rocha caindo também pode alterar a configuração do mapa, ela também aparece aqui
	
		# Dig Dug
		
		lw a0, DIGDUG_TOP_X
		lw a1, DIGDUG_TOP_Y
		li t0, 10
		div a0, a0, t0
		div a1, a1, t0
		addi a0, a0, 1
		addi a1, a1, 1
		li a3, 18
		li a4, 18
		la a5, GAME_MAP
		WRITE_TO_BUFFER(GAP_DATA, 18, zero, a3, a4, a0, a1, a5)



COLLISION_TEST: # Passar teste de colisão para depois da renderização


RENDER_OBJECTS:

		# Usamos a booleana DIGDUG_DIGGING para determinar se irá cavar (substituir o background) ou não.
		# Usa-se 2 camadas para representar as divisórias horizontais e verticais
		# Se Dig Dug se mover horizontalmente, apaga as divisórias verticais, e vice-versa
		lw t0, DIGDUG_DIGGING
		beq t0, zero, REDRAW_BG
		

		lw t0, DIGDUG_DIRECTION
		lw a0, DIGDUG_TOP_X
		lw a1, DIGDUG_TOP_Y
		
		# Testamos a direção
		beq t0, zero, DIGDUG_DIGGING_UP
		li t1, 1
		beq t0, t1, DIGDUG_DIGGING_DOWN
		li t1, 2
		beq t0, t1, DIGDUG_DIGGING_LEFT
		
		# t4: Buffer a ser apagado
		
	DIGDUG_DIGGING_RIGHT:
		la t4, BACKGROUND_V_BUFFER
		la t5, BACKGROUND_H_BUFFER
		#addi a0, a0, 10
		li t2, 20
		li s11, 10
		j DIGDUG_BG_REDRAW
	DIGDUG_DIGGING_LEFT:
		la t4, BACKGROUND_V_BUFFER
		la t5, BACKGROUND_H_BUFFER
		addi a0, a0, 10
		li t2, 20
		li s11, 10
		j DIGDUG_BG_REDRAW
	DIGDUG_DIGGING_UP:
		la t4, BACKGROUND_H_BUFFER
		la t5, BACKGROUND_V_BUFFER
		li t2, 10
		li s11, 20
		j DIGDUG_BG_REDRAW
	DIGDUG_DIGGING_DOWN:
		la t4, BACKGROUND_H_BUFFER
		la t5, BACKGROUND_V_BUFFER
		li t2, 10
		li s11, 20
		addi a1, a1, 10
		
		
	DIGDUG_BG_REDRAW:
		# Cálculo de coordenadas no display
		li t0, 10
		div a0, a0, t0
		div a1, a1, t0
		# Cálculo de offset
		li t1, 320
		mul a1, a1, t1			
		add a3, a1, a0
		li t3, DISPLAY_ADDR
		add t3, t3, a3
		add t4, t4, a3
		add t5, t5, a3

		# Em um loop só, apagamos e substituímos o background
	DIGDUG_REPLACE_BG:
		beq t2, zero, DIGDUG_REPLACE_BG_END
		mv t1, s11
		DIGDUG_REPLACE_BG_INNER:
			beq t1, zero, DIGDUG_REPLACE_BG_INNER_END	
			li t6, 0x0
			sb t6, (t4)				
			lb t0, (t5)
			sb t0, (t3)	
			addi t3, t3, 1
			addi t4, t4, 1
			addi t5, t5, 1
			addi t1, t1, -1
			j DIGDUG_REPLACE_BG_INNER
		DIGDUG_REPLACE_BG_INNER_END:

		addi t3, t3, 320
		sub t3, t3, s11
		addi t5, t5, 320
		sub t5, t5, s11
		addi t4, t4, 320
		sub t4, t4, s11
		addi t2, t2, -1
		j DIGDUG_REPLACE_BG
	DIGDUG_REPLACE_BG_END:
	j DRAW_DIGDUG
		
	
	REDRAW_BG:
		# Redesenho de fundo
		lw a3, DIGDUG_TOP_X_P
		lw a4, DIGDUG_TOP_Y_P
		li t0, 10
		div a3, a3, t0
		div a4, a4, t0
	
		li a0, 20
		li a1, 20
		#########################################
		# Otimizar não usando DIGDUG_BG_DATA ###
		#########################################
		DRAW_IMG(DIGDUG_BG_DATA, 20, zero, a0, a1, a3, a4)
	
		lw t0, DIGDUG_TOP_X
		li t6, 10
		div t0, t0, t6
	
		lw t1, DIGDUG_TOP_Y
		div t1, t1, t6
	
		li t3, 320
		mul t1, t1, t3
		add t0, t1, t0
		la t5, BACKGROUND_BUFFER
		add t0, t0, t5
		la t2, DIGDUG_BG_DATA
		li t3, 20
		li t5, 20
	
	SAVE_BG_DATA_OUTER:
		beq t5, zero, SAVE_BG_DATA_DONE
		li t3, 20
		SAVE_BG_DATA_INNER:
			beq t3, zero, SAVE_BG_DATA_INNER_DONE
			# 4 por vez
			lb t4, (t0)
			sb t4, (t2)
			addi t0, t0, 1
			addi t2, t2, 1
	
			addi t3, t3, -1
			j SAVE_BG_DATA_INNER
		SAVE_BG_DATA_INNER_DONE:
		addi t0, t0, 300
		addi t5, t5, -1
		j SAVE_BG_DATA_OUTER
	SAVE_BG_DATA_DONE:
	
	
	DRAW_DIGDUG:
		# Desenhando Dig Dug
		# Se não estiver cavando, usar transparência
	
		lw a3, DIGDUG_TOP_X
		lw a4, DIGDUG_TOP_Y
		li t0, 10
		div a3, a3, t0
		div a4, a4, t0
		addi a3, a3, 1
		addi a4, a4, 1
	
		li a0, 0
		li a1, 18
		li a2, 18
	
		DRAW_IMG(DIGDUG_SPRT_SHEET, 36, a0, a1, a2, a3, a4)
		
	# Pookas(s)
	
	# Checa se há Pookas para desenhar
	DRAW_POOKA:
		lb t0, GAME_POOKA_COUNT
		beq t0, zero, DRAW_POOKA_END
		
	# TO-DO - Fazer quatro checks em vez de um só com um loop
	
		la t0, GAME_POOKA_BUFFER
		addi t0, t0, POOKA_POS_OFFSET
		
		lw a0, (t0)
		lw a1, 4(t0)
		li t1, 10
		div a0, a0, t1
		div a1, a1, t1
		addi a0, a0, 5
		addi a1, a1, 5
		
		li a2, 10937
		li a3, 12
		li a4, 12
		
		DRAW_IMG(SPRITE_SHEET_BUFFER, 154, a2, a3, a4, a0, a1)
		
		
	DRAW_POOKA_END:
	
	
	
	
WAIT:
	# Calcula quanto tempo esperar até a próxima atualização, printa esse tempo
	GET_TIME(t1)			# Pegamos o tempo no final do loop, após todas as computações
	addi s0, s0, TIME_STEP  	# Adicionamos o intervalo que queremos, para decidir o momento da próxima atualização
	sub s0, s0, t1			# Subtraímos o tempo no final do loop do valor anterior para sabermos quanto tempo esperar

	mv a0, s0			# Printamos esse valor
	li a7, 1
	ecall
	
	#mv a0, s5
	#li a7, 1
	#ecall
	
	#li a0, 0x020
	#li a7, 11
	#ecall
	
	#mv a0, s6
	#li a7, 1
	#ecall
	
	
	li a0, 10			# Printamos 'new line', para pular para a próxima linha no I/O
	li a7, 11
	ecall
	
	WAIT(s0)
	
	j MAIN

END:	
	# DEBUG, remover depois
	li a0, 320
	li a1, 240
	DRAW_IMG(GAME_MAP, 320, zero, a0, a1, zero, zero)
	li a7, 10			# Termina o programa
	ecall
