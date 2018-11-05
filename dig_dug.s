# Lembrar de colocar o valor máximo em cada váriavel.
# Nunca usar t5 e t6. Registradores reservados para macros.

# TO-DO List
# - Calcular quanto espaço cada inimigo usa.
# - Com isso, definir espaço máximo a ser alocado para os inimigos em cada fase.
# - Definir o que fazer quando o intervalo de Wait for negativo (loop demorou mais que o time step)


# Constantes globais
.eqv INPUT_DATA_ADDR   0xFF200004	# Endereço onde é armazenado caracteres de entrada
.eqv INPUT_RDY_ADDR    0xFF200000	# Endereço com a informação sobre o estado do buffer de input. 1: pronto, 0: vazio
.eqv INPUT_FINISH      0x030		# Caractere de finalização	

.eqv TIME_STEP         0x030		# Intervalo entre atualizações, em milissegundos

.eqv DISPLAY_ADDR      0xFF000000	# Endereço do display

.eqv DIGDUG_BS_SPEED   0x06		# Velocidade de Dig Dug

# Limites

.eqv WORLD_EDGE_X      3190		# Limites do mundo do jogo
.eqv WORLD_EDGE_Y      2390

.data

# Estado do jogo
GAME_SCORE: 	.word 0x00000000
GAME_HISCORE: 	.word 0x00000000
GAME_STAGE: 	.byte 0


#################################
# Dados do Dig Dug (personagem) #
#################################

DIGDUG_LIVES: .byte 5

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

############
# Inimigos #
############

# Pooka

POOKA_IN: 1

POOKA_SPEED_X: 2
POOKA_SPEED_Y: 2

POOKA_TOP_X: 255
POOKA_TOP_Y: 255
POOKA_BOT_X: 255
POOKA_BOT_Y: 255

# Fygar

FYGAR_IN: 1

FYGAR_SPEED_X: 2
FYGAR_SPEED_Y: 2

FYGAR_TOP_X: 255
FYGAR_TOP_Y: 255
FYGAR_BOT_X: 255
FYGAR_BOT_Y: 255


# Dados de imagem

SPRITE_SHEET_PATH: 	.asciz "digdug_sprtsheet.bin"
SPRITE_SHEET_BUFFER: 	.space 42504
BACKGROUND_PATH: 	.asciz "digdug_background.bin"
BACKGROUND_BUFFER:      .space 76800

.text

# Funções

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
.macro LOAD_DATA (%file_l, %label, %size)
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
.macro DRAW_IMG (%address, %offset, %width, %cropw, %croph, %posx, %posy)
	la t0, %address					# Adicionamos ao endereço de início o offset desejado
	li t1, %offset
	add t0, t0, t1
	
	# Calculamos qual endereço onde começar a desenhar
	mv t3, %posy					# Primeiro pegamos a coordenada Y
	li t1, 320					# Multiplicamos pela largura do display para chegarmos na linha certa
	mul t3, t3, t1			
	add t3, t3, %posx				# Adiciona-se o valor da cordenada X, para chegar na coluna certa
	li t1, DISPLAY_ADDR				# A tudo isso, adicionamos o endereço onde começa o buffer de display
	add t3, t3, t1
	
	li t2, %croph
	# t0: endereço da imagem na memória
	# t1: número de intervalos de 4 pixels, por linha, a desenhar
	# t2: número de linhas a desenhar
	# t3: endereço do buffer de display a desenhar
START_DRAW:
	beq t2, zero, END_DRAW				# Se o número de linhas a desenhar for zero, o loop acaba
	li t1, %cropw
	srli t1, t1, 2
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
		
		lb t4, (t0)			
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

	li t5, %cropw					# Offset na imagem: (largura do arquivo) - (largura do segmento)
	addi t0, t0, %width
	sub t0, t0, t5
	addi t3, t3, 320				# Offset no buffer: (largura do display) - (largura do segmento)
	sub t3, t3, t5
	
	addi t2, t2, -1 				# Uma linha a menos a desenhar
	j START_DRAW
END_DRAW:
	
.end_macro

# Desenha uma imagem armazenada em memória na tela, na posição especificada, com transparência (cor preta, ou rgb 0, 0, 0)
# %address: endereço da imagem; %offset: onde começar a ler; %width: largura da imagem; %cropw: largura do segmento; %croph: altura do segmento
# %posx: coordenada X da tela; %posy: coordenada Y da tela
.macro DRAW_IMG_TR (%address, %offset, %width, %cropw, %croph, %posx, %posy)
	la t0, %address					# Adicionamos ao endereço de início o offset desejado
	li t1, %offset
	add t0, t0, t1
	
	# Calculamos qual endereço onde começar a desenhar
	mv t3, %posy					# Primeiro pegamos a coordenada Y
	li t1, 320					# Multiplicamos pela largura do display para chegarmos na linha certa
	mul t3, t3, t1			
	add t3, t3, %posx				# Adiciona-se o valor da cordenada X, para chegar na coluna certa
	li t1, DISPLAY_ADDR				# A tudo isso, adicionamos o endereço onde começa o buffer de display
	add t3, t3, t1
	
	li t2, %croph
	# t0: endereço da imagem na memória
	# t1: número de pixels por linha a desenhar
	# t2: número de linhas a desenhar
	# t3: endereço do buffer de display a desenhar
	# Agora, leremos cada pixel individualmente, com a ajuda de dois loops, um interior ao outro
START_DRAW:
	beq t2, zero, END_DRAW				# Se o número de linhas a desenhar for zero, o loop acaba
	li t1, %cropw
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

	li t5, %cropw					# Offset na imagem: (largura do arquivo) - (largura do segmento)
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
	
	# Carrega os arquivos de imagem
	LOAD_DATA(BACKGROUND_PATH, BACKGROUND_BUFFER, 76800)
	LOAD_DATA(SPRITE_SHEET_PATH, SPRITE_SHEET_BUFFER, 42504)
	
	# Depois mudar isto de posição
	DRAW_IMG(BACKGROUND_BUFFER, 0, 320, 320, 240, x0, x0)

	li s6, 1 # Bool para MOVEMENT TEST
	
MAIN: 
	lw t0, INPUT_RDY_ADDR		# Vemos se há caractere a ler
	beq t0, zero, GET_CURRENT_TIME  
	lw t0, INPUT_DATA_ADDR   	# Termina o loop se recebermos o caractere desejado
	li t1, INPUT_FINISH		# Caractere desejado
	beq t0, t1, END			# Teste
	mv s2, t0			# Colocamos o caractere em buffer para uso futuro
	
GET_CURRENT_TIME:
	GET_TIME(s0) 			# Pegamos o tempo no começo do loop
	


MOVEMENT_TEST_SETUP: beq s6, zero, MOVEMENT_TEST_SETUP_DONE
	# Posição inicial
	# Escala da representação virtual de espaço para pixels é 10:1
	
	SET_VALUE_IMM(DIGDUG_TOP_X, 200)
	SET_VALUE_IMM(DIGDUG_TOP_Y, 400)
	SET_VALUE_IMM(DIGDUG_BOT_X, 390)
	SET_VALUE_IMM(DIGDUG_BOT_Y, 590)
	li s6, 0
MOVEMENT_TEST_SETUP_DONE:

	# trocar nome de DIGDUG_SPEEDX/Y para CURRENT_SPEED ou algo parecido
	# Adicionar váriavel para armazenar direção, para decidir qual sprite usar
	
	mv t0, s2
	li t1, 0x077			# substituir por eqv depois
	beq t0, t1, DIGDUG_MOVE_UP
	li t1, 0x061
	beq t0, t1, DIGDUG_MOVE_LEFT
	li t1, 0x073
	beq t0, t1, DIGDUG_MOVE_DOWN
	li t1, 0x64
	beq t0, t1, DIGDUG_MOVE_RIGHT
	j DIGDUG_CALC_NEXT_POS
	
DIGDUG_MOVE_UP:
	# talvez colocar current speed in registradores, se for mais rápido e precisarmos da velocidade
	li t1, 0xFFFFFFFF
	li t2, DIGDUG_BS_SPEED
	sub t1, t1, t2
	addi t1, t1, 0x01
	SET_VALUE_REG(DIGDUG_SPEED_Y, t1)
	SET_VALUE_REG(DIGDUG_SPEED_X, zero)
	j DIGDUG_CALC_NEXT_POS
	
DIGDUG_MOVE_DOWN:
	li t1, 3
	li t1, DIGDUG_BS_SPEED
	SET_VALUE_REG(DIGDUG_SPEED_Y, t1)
	SET_VALUE_REG(DIGDUG_SPEED_X, zero)
	j DIGDUG_CALC_NEXT_POS

DIGDUG_MOVE_LEFT:
	li t1, 0xFFFFFFFF
	li t2, DIGDUG_BS_SPEED
	sub t1, t1, t2
	addi t1, t1, 0x01
	SET_VALUE_REG(DIGDUG_SPEED_X, t1)
	SET_VALUE_REG(DIGDUG_SPEED_Y, zero)
	j DIGDUG_CALC_NEXT_POS
	
DIGDUG_MOVE_RIGHT:
	li t1, 3
	li t1, DIGDUG_BS_SPEED
	SET_VALUE_REG(DIGDUG_SPEED_X, t1)
	SET_VALUE_REG(DIGDUG_SPEED_Y, zero)
	j DIGDUG_CALC_NEXT_POS

DIGDUG_CALC_NEXT_POS:

	# Depois inserir teste de posição válida

	lw t1, DIGDUG_TOP_X
	lw t2, DIGDUG_SPEED_X
	add t1, t1, t2
	SET_VALUE_REG(DIGDUG_TOP_X, t1)
	
	lw t1, DIGDUG_TOP_Y
	lw t2, DIGDUG_SPEED_Y
	add t1, t1, t2
	SET_VALUE_REG(DIGDUG_TOP_Y, t1)


RENDER_OBJECTS:
	
	# Desenhando Dig Dug
	# Trocar nomes para DIGDUG_CURRENT_TOP_*
	# Antes disso desenhar background novo na posição anterior
	# Usar um sprite branco e preto com operação lógica AND
	
	lw t5, DIGDUG_TOP_X
	lw t6, DIGDUG_TOP_Y
	li t2, 10
	divu t5, t5, t2
	divu t6, t6, t2
	addi t6, t6, 8
	
	DRAW_IMG(SPRITE_SHEET_BUFFER, 4340, 154, 12, 13, t5, t6)
	
	
WAIT:
	# Calcula quanto tempo esperar até a próxima atualização, printa esse tempo
	GET_TIME(t1)			# Pegamos o tempo no final do loop, após todas as computações
	addi s0, s0, TIME_STEP  	# Adicionamos o intervalo que queremos, para decidir o momento da próxima atualização
	sub s0, s0, t1			# Subtraímos o tempo no final do loop do valor anterior para sabermos quanto tempo esperar
	
	mv a0, s0			# Printamos esse valor
	li a7, 1
	ecall
	li a0, 10			# Printamos 'new line', para pular para a próxima linha no I/O
	li a7, 11
	ecall
	
	WAIT(s0)
	
	j MAIN

END:	li a7, 10			# Termina o programa
	ecall
