# Lembretes
# - 
# TO-DO List
# - Calcular quanto espa�o cada inimigo usa.
# - Com isso, definir espa�o m�ximo a ser alocado para os inimigos em cada fase.
# - Atualizar Bot_x e Bot_y (usar Top_x e Top_y como base)
# - Otimizar algumas fun��es usando uma booleana para impedir que executem quando n�o houve movimento


# Constantes globais
.eqv INPUT_DATA_ADDR   0xFF200004	# Endere�o onde � armazenado caracteres de entrada
.eqv INPUT_RDY_ADDR    0xFF200000	# Endere�o com a informa��o sobre o estado do buffer de input. 1: pronto, 0: vazio
.eqv INPUT_FINISH      0x030		# Caractere de finaliza��o	

.eqv TIME_STEP         0x030		# Intervalo entre atualiza��es, em milissegundos
.eqv DISPLAY_ADDR      0xFF000000	# Endere�o do display
.eqv DIGDUG_BS_SPEED   0x0A		# Velocidade de Dig Dug (No momento, precisa ser menor que 10, sen�o quebra o jogo
# Controles
.eqv GAME_UP_KEY       0x077		# w
.eqv GAME_DW_KEY       0x073		# s	
.eqv GAME_LF_KEY       0x061		# a
.eqv GAME_RT_KEY       0x064		# d
.eqv GAME_ATK_KEY      0x06C		# l


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

# Cores de fundo da posi��o atual do personagem, para redesenho
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

POOKA_IN: .byte 1

POOKA_SPEED_X: .word 2
POOKA_SPEED_Y: .word 2

POOKA_TOP_X: .word 255
POOKA_TOP_Y: .word 255
POOKA_BOT_X: .word 255
POOKA_BOT_Y: .word 255

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
BACKGROUND_PATH: 	.asciz "bin/digdug_background.bin"
BACKGROUND_BUFFER:      .space 76800
TUNNEL_M_PATH:		.asciz "bin/tunnel_mask.bin"
TUNNEL_MASK:		.space 400

# Representa��o virtual dos t�neis

GAME_MAP: 		.space 76800
GAP_DATA:		.space 324
GAP_DATA_PATH:		.asciz "bin/gap.bin"
LEVEL_1_PATH: 		.asciz "bin/digdug_level_01.bin"
LEVEL_2_PATH: 		.asciz "placeholder"
LEVEL_3_PATH: 		.asciz "placeholder"
LEVEL_4_PATH: 		.asciz "placeholder"
LEVEL_5_PATH: 		.asciz "placeholder"


.text

# Fun��es

# Acha o tempo atual e armazena o valor no registrador %reg
.macro GET_TIME (%reg)
	li a7, 30
	ecall
	mv %reg, a0
.end_macro

# Pausa o programa pelo tempo no registrador %reg, em milissegundos
.macro WAIT (%reg)
	mv a0, %reg
	bgez a0, NORMAL_TIME_STEP	# Caso o loop demore demais, n�o esperamos nada
	li a0, 0		
NORMAL_TIME_STEP:
	li a7, 32
	ecall
.end_macro

# Abre, carrega um arquivo em mem�ria, na label dada, fecha o arquivo. � preciso ter certeza que o espa�o necess�rio j� foi reservado
.macro LOAD_FILE (%file_l, %label, %size)
	la a0, %file_l			# Abrimos o arquivo usando o caminho armazenado na label
	li a1, 0
	li a7, 1024
	ecall				# Descriptor � colocado em a0, que iremos utilizar a seguir
	mv t0, a0			# Descriptor � armazenado t0, sen�o ser� perdido na pr�xima chamada
	
	la a1, %label			# Endere�o onde os dados ser�o armazenados
	li a2, %size			# Tamanho a armazenar
	li a7, 63
	ecall
	
	mv a0, t0			# Fechamos o arquivo
	li a7, 57
	ecall
.end_macro

# Dividimos a fun��o de desenho em "Desenhar" e "Desenhar com transpar�ncia" porque o uso de transpar�ncia � mais custoso
# e nem sempre precisamos dela

# Desenha uma imagem armazenada em mem�ria na tela, na posi��o especificada
# largura do segmento PRECISA ser m�ltipla de 4
# %address: endere�o da imagem; %offset: onde come�ar a ler; %width: largura da imagem; %cropw: largura do segmento; %croph: altura do segmento
# %posx: coordenada X da tela; %posy: coordenada Y da tela
.macro DRAW_IMG (%address, %width, %offset, %cropw, %croph, %posx, %posy)
	la t0, %address					# Adicionamos ao endere�o de in�cio o offset desejado
	mv t1, %offset
	add t0, t0, t1
	
	# Calculamos qual endere�o onde come�ar a desenhar
	mv t3, %posy					# Primeiro pegamos a coordenada Y
	li t1, 320					# Multiplicamos pela largura do display para chegarmos na linha certa
	mul t3, t3, t1			
	add t3, t3, %posx				# Adiciona-se o valor da cordenada X, para chegar na coluna certa
	li t1, DISPLAY_ADDR				# A tudo isso, adicionamos o endere�o onde come�a o buffer de display
	add t3, t3, t1
	
	mv t2, %croph
	# t0: endere�o da imagem na mem�ria
	# t1: n�mero de intervalos de 4 pixels, por linha, a desenhar
	# t2: n�mero de linhas a desenhar
	# t3: endere�o do buffer de display a desenhar
START_DRAW:
	beq t2, zero, END_DRAW				# Se o n�mero de linhas a desenhar for zero, o loop acaba
	mv t1, %cropw
	srli t1, t1, 2
	DRAW_PIXEL:			
		beq t1, zero, END_DRAW_PIXEL		# Se o n�mero de pixels na linha a desenhar for zero, sa�mos do loop interior
		
		lb t4, (t0)				# Armazena a cor em t4 temporariamente
		sb t4, (t3)				

		addi t0, t0, 1				# Passa para o pr�ximo pixel
		addi t3, t3, 1
		
		lb t4, (t0)
		sb t4, (t3)
		
		addi t0, t0, 1				# Passa para o pr�ximo pixel
		addi t3, t3, 1
		
		lb t4, (t0)			
		sb t4, (t3)				

		addi t0, t0, 1				# Passa para o pr�ximo pixel
		addi t3, t3, 1
		
		lb t4, (t0)
		sb t4, (t3)
		
		addi t0, t0, 1				# Passa para o pr�ximo pixel
		addi t3, t3, 1
		
		addi t1, t1, -1				# Um intervalo a menos a desenhar
		j DRAW_PIXEL
	END_DRAW_PIXEL:
	# Terminamos de desenhar a linha, passamos para a pr�xima

	mv t5, %cropw					# Offset na imagem: (largura do arquivo) - (largura do segmento)
	addi t0, t0, %width
	sub t0, t0, t5
	addi t3, t3, 320				# Offset no buffer: (largura do display) - (largura do segmento)
	sub t3, t3, t5
	
	addi t2, t2, -1 				# Uma linha a menos a desenhar
	j START_DRAW
END_DRAW:
	
.end_macro

# Similar ao DRAW_IMG, mas para a representa��o invis�vel do mapa de jogo.
# %address: endere�o de leitura; %offset: onde come�ar a ler; %width: largura da imagem; %cropw: largura do segmento; %croph: altura do segmento
# %posx: coordenada X da tela; %posy: coordenada Y da tela
.macro WRITE_TO_MAP (%address, %width, %offset, %cropw, %croph, %posx, %posy, %map_addr)
	la t0, %address					# Adicionamos ao endere�o de in�cio o offset desejado
	mv t1, %offset
	add t0, t0, t1
	
	# Calculamos qual endere�o onde come�ar a desenhar
	mv t3, %posy					# Primeiro pegamos a coordenada Y
	li t1, 320					# Multiplicamos pela largura do display para chegarmos na linha certa
	mul t3, t3, t1			
	add t3, t3, %posx				# Adiciona-se o valor da cordenada X, para chegar na coluna certa
	mv t1, %map_addr				# A tudo isso, adicionamos o endere�o onde come�a o buffer de display
	add t3, t3, t1
	
	mv t2, %croph
	# t0: endere�o da imagem na mem�ria
	# t1: n�mero de pixels por linha a desenhar
	# t2: n�mero de linhas a desenhar
	# t3: endere�o do buffer de display a desenhar
	# Agora, leremos cada pixel individualmente, com a ajuda de dois loops, um interior ao outro
START_DRAW:
	beq t2, zero, END_DRAW				# Se o n�mero de linhas a desenhar for zero, o loop acaba
	mv t1, %cropw
	DRAW_PIXEL:			
		beq t1, zero, END_DRAW_PIXEL		# Se o n�mero de pixels na linha a desenhar for zero, sa�mos do loop interior
		lb t4, (t0)				# Armazena a cor em t4 temporariamente
		sb t4, (t3)				# Desenhamos o pixel no buffer de display
		addi t0, t0, 1				# Passa para o pr�ximo pixel
		addi t3, t3, 1
		addi t1, t1, -1				# Um pixel a menos a desenhar
		j DRAW_PIXEL
	END_DRAW_PIXEL:
	# Terminamos de desenhar a linha, passamos para a pr�xima

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
	la t0, %address					# Adicionamos ao endere�o de in�cio o offset desejado
	mv t1, %offset
	add t0, t0, t1
	
	# Calculamos qual endere�o onde come�ar a desenhar
	mv t3, %posy					# Primeiro pegamos a coordenada Y
	li t1, 320					# Multiplicamos pela largura do display para chegarmos na linha certa
	mul t3, t3, t1			
	add t3, t3, %posx				# Adiciona-se o valor da cordenada X, para chegar na coluna certa
	li t1, DISPLAY_ADDR				# A tudo isso, adicionamos o endere�o onde come�a o buffer de display
	add t3, t3, t1
	
	mv t2, %croph
	# t0: endere�o da imagem na mem�ria
	# t1: n�mero de pixels por linha a desenhar
	# t2: n�mero de linhas a desenhar
	# t3: endere�o do buffer de display a desenhar
	# Agora, leremos cada pixel individualmente, com a ajuda de dois loops, um interior ao outro
START_DRAW:
	beq t2, zero, END_DRAW				# Se o n�mero de linhas a desenhar for zero, o loop acaba
	mv t1, %cropw
	DRAW_PIXEL:			
		beq t1, zero, END_DRAW_PIXEL		# Se o n�mero de pixels na linha a desenhar for zero, sa�mos do loop interior
		lb t4, (t0)				# Armazena a cor em t4 temporariamente
		beq t4, zero, TEST_TRANSP		# Se a cor do pixel for preta, n�o desenhamos
		sb t4, (t3)				# Desenhamos o pixel no buffer de display
	TEST_TRANSP:
		addi t0, t0, 1				# Passa para o pr�ximo pixel
		addi t3, t3, 1
		addi t1, t1, -1				# Um pixel a menos a desenhar
		j DRAW_PIXEL
	END_DRAW_PIXEL:
	# Terminamos de desenhar a linha, passamos para a pr�xima

	mv t5, %cropw					# Offset na imagem: (largura do arquivo) - (largura do segmento)
	addi t0, t0, %width
	sub t0, t0, t5
	addi t3, t3, 320				# Offset no buffer: (largura do display) - (largura do segmento)
	sub t3, t3, t5
	
	addi t2, t2, -1					# Uma linha a menos a desenhar
	j START_DRAW
END_DRAW:
.end_macro


# Muda o valor de uma label - Sempre estar ciente do valor m�ximo que pode armazenar
.macro SET_VALUE_IMM (%label, %value)
	la t0, %label		# Armazena endere�o da label em t0
	li t1, %value		# Armazena valor em t1
	sw t1, 0(t0)		# Muda o valor no endere�o t5 para o valor t6
.end_macro

# Muda o valor de uma label, usando um registrador - Sempre estar ciente do valor m�ximo que pode armazenar
# N�o usar registrador t0 como par�metro dessa fun��o
.macro SET_VALUE_REG (%label, %reg)
	la t0, %label		# Armazena endere�o da label em t0
	mv t1, %reg		# Armazena valor em t1
	sw t1, 0(t0)		# Muda o valor no endere�o t5 para o valor t6
.end_macro
######################################
######################################
#	 Come�o do programa	     #
######################################
######################################
	
	# To-do: Decidir quais arquivos s� precisam ser carregados uma vez de fato
	
	# Carrega os arquivos de imagem
	LOAD_FILE(BACKGROUND_PATH, BACKGROUND_BUFFER, 76800)
	LOAD_FILE(SPRITE_SHEET_PATH, SPRITE_SHEET_BUFFER, 42504)
	LOAD_FILE(GAP_DATA_PATH, GAP_DATA, 324)
	LOAD_FILE(TUNNEL_M_PATH, TUNNEL_MASK, 400)

	# Carrega mapa de jogo
	LOAD_FILE(LEVEL_1_PATH, GAME_MAP, 76800)
	
	li a0, 320
	li a1, 240
	# Depois mudar isto de posi��o
	DRAW_IMG(BACKGROUND_BUFFER, 320, zero, a0, a1, zero, zero)

	li s6, 1 # Bool para MOVEMENT TEST - Remover depois
	
MAIN: 
	lw t0, INPUT_RDY_ADDR		# Vemos se h� caractere a ler
	beq t0, zero, GET_CURRENT_TIME  
	lw t0, INPUT_DATA_ADDR   	# Termina o loop se recebermos o caractere desejado
	li t1, INPUT_FINISH		# Caractere desejado
	beq t0, t1, END			# Teste
	mv s2, t0			# Colocamos o caractere em buffer para uso futuro
	
GET_CURRENT_TIME:
	GET_TIME(s0) 			# Pegamos o tempo no come�o do loop
	
	# Pular para endere�o da sess�o do jogo relevante
	# Sess�es: Tela inicial, Controles, Anima��o inicial, Fase
	
	
	# Formato da anima��o inicial
	# Dire��o > Coordernada de mudan�a > Nova dire��o

###
MOVEMENT_TEST_SETUP: beq s6, zero, MOVEMENT_TEST_SETUP_DONE
	# Posi��o inicial
	# Escala da representa��o virtual de espa�o para pixels � 10:1
	
	SET_VALUE_IMM(DIGDUG_TOP_X, 200)
	SET_VALUE_IMM(DIGDUG_TOP_Y, 400)
	SET_VALUE_IMM(DIGDUG_BOT_X, 390)
	SET_VALUE_IMM(DIGDUG_BOT_Y, 590)
	
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
	# Pegamos o input recebido, que est� armazenado em s2, testamos para ver se � uma dire��o v�lida
	
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
		# Mudamos a velocidade de Dig Dug - magnitude, dire��o e sentido
		# Checamos se � uma posi��o v�lida para mudan�a de dire��o - X e Y precisam ser m�ltiplos de 20
		# A checagem s� � feita se houver mudan�a de dire��o
		lw t0, DIGDUG_DIRECTION
		li t1, 1
		ble t0, t1, DIGDUG_MOVE_UP_OK		# Se Dig Dug n�o mudar de dire��o, ignoramos o pr�ximo teste
		lw t0, DIGDUG_TOP_X
		lw t1, DIGDUG_TOP_Y
		li t2, 200				# Testamos se a posi��o atual se alinha com a grade. Adiciona-se 200 para o caso de coordenada igual a zero
		li t3, 10				
		add t0, t0, t2
		add t1, t1, t2
		div t0, t0, t3				# Divide-se por dez para conseguir coordenada em rela��o ao display 320x240
		div t1, t1, t3
		li t2, 20
		rem t0, t0, t2				# Testamos se as coordenadas s�o m�ltiplas de 20
		rem t1, t1, t2
		bne t0, zero, DIGDUG_CALC_NEXT_POS
		bne t1, zero, DIGDUG_CALC_NEXT_POS
	DIGDUG_MOVE_UP_OK:
		li a0, 0xFFFFFFFF		# Move-se para cima. O componente Y da velocidade deve ser negativo, ent�o convertemos
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
		li a0, 0xFFFFFFFF		# Move-se para a esquerda. O componente X da velocidade deve ser negativo, ent�o convertemos
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

	DIGDUG_ATTACK:

DIGDUG_CALC_NEXT_POS:
	
		# Guardamos a posi��o atual
		lw a0, DIGDUG_TOP_X
		SET_VALUE_REG(DIGDUG_TOP_X_P, a0)
		lw a0, DIGDUG_TOP_Y
		SET_VALUE_REG(DIGDUG_TOP_Y_P, a0)
		lw a0, DIGDUG_BOT_X
		SET_VALUE_REG(DIGDUG_BOT_X_P, a0)
		lw a0, DIGDUG_BOT_Y
		SET_VALUE_REG(DIGDUG_BOT_Y_P, a0)
	
		# Checa se Dig Dug n�o saiu da borda do jogo. Testamos X e Y.
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
	
		# Colocar checagem se est� cavando ou n�o
		# Para isso, testar TOP e BOT
	
UPDATE_GAME_MAP:


		# Checamos se Dig Dug cavou algo e atualizamos o mapa
		# Como a rocha caindo tamb�m pode alterar a configura��o do mapa, ela tamb�m aparece aqui
	
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
		WRITE_TO_MAP(GAP_DATA, 18, zero, a3, a4, a0, a1, a5)



COLLISION_TEST:


RENDER_OBJECTS:
#################################### ESTOU AQUI ########################################################@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
########################################################################################################@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

		# Usamos a booleana DIGDUG_DIGGING para determinar se ir� cavar (substituir o background) ou n�o.

		lw t0, DIGDUG_DIGGING
		beq t0, zero, REDRAW_BG
		
		lw a0, DIGDUG_TOP_X
		lw a1, DIGDUG_TOP_Y
		
		li t0, 10
		div a0, a0, t0
		div a1, a1, t0
		
		la t0, TUNNEL_MASK
		
		li t1, 320
		mul a1, a1, t1			
		add a3, a1, a0
		li t3, DISPLAY_ADDR
		add t3, a3, t3
		li t2, 20
		# t0: endere�o da imagem na mem�ria
		# t1: n�mero de pixels por linha a desenhar
		# t2: n�mero de linhas a desenhar
		# t3: endere�o do buffer de display a desenhar
		# Agora, leremos cada pixel individualmente, com a ajuda de dois loops, um interior ao outro
	DRAW_MASK:
		beq t2, zero, DRAW_MASK_END				# Se o n�mero de linhas a desenhar for zero, o loop acaba
		li t1, 20
		DRAW_MASK_INNER:
			beq t1, zero, DRAW_MASK_INNER_END	
			lb t4, (t0)				# Armazena a cor em t4 temporariamente
			lb t5, (t3)
			and t4, t4, t5
			sb t4, (t3)				# Desenhamos o pixel no buffer de display
			addi t0, t0, 1				# Passa para o pr�ximo pixel
			addi t3, t3, 1
			addi t1, t1, -1				# Um pixel a menos a desenhar
			j DRAW_MASK_INNER
		DRAW_MASK_INNER_END:

		addi t3, t3, 320				# Offset no buffer: (largura do display) - (largura do segmento)
		li t5, 20
		sub t3, t3, t5
		addi t2, t2, -1					# Uma linha a menos a desenhar
		j DRAW_MASK
	DRAW_MASK_END:
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
		# Otimizar n�o usando DIGDUG_BG_DATA ###
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
		# Trocar nomes para DIGDUG_CURRENT_TOP_*
		# Antes disso desenhar background novo na posi��o anterior
		# Usar um sprite branco e preto com opera��o l�gica AND
	
		lw a3, DIGDUG_TOP_X
		lw a4, DIGDUG_TOP_Y
		li t0, 10
		div a3, a3, t0
		div a4, a4, t0
		addi a3, a3, 4
		addi a4, a4, 4
	
		li a0, 4340
		li a1, 12
		li a2, 13
	
		DRAW_IMG(SPRITE_SHEET_BUFFER, 154, a0, a1, a2, a3, a4)
	
	
WAIT:
	# Calcula quanto tempo esperar at� a pr�xima atualiza��o, printa esse tempo
	GET_TIME(t1)			# Pegamos o tempo no final do loop, ap�s todas as computa��es
	addi s0, s0, TIME_STEP  	# Adicionamos o intervalo que queremos, para decidir o momento da pr�xima atualiza��o
	sub s0, s0, t1			# Subtra�mos o tempo no final do loop do valor anterior para sabermos quanto tempo esperar

	mv a0, s0			# Printamos esse valor
	li a7, 1
	ecall
	
	#lw a0, DIGDUG_TOP_X
	#li a7, 1
	#ecall
	
	#li a0, 0x020
	#li a7, 11
	#ecall
	
	#lw a0, DIGDUG_TOP_Y
	#li a7, 1
	#ecall
	
	
	li a0, 10			# Printamos 'new line', para pular para a pr�xima linha no I/O
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
