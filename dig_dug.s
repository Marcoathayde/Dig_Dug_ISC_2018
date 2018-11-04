# Lembrar de colocar o valor m�ximo em cada v�riavel.
# Nunca usar t5 e t6. Registradores reservados para macros.

# TO-DO List
# - Calcular quanto espa�o cada inimigo usa.
# - Com isso, definir espa�o m�ximo a ser alocado para os inimigos em cada fase.
# - Definir o que fazer quando o intervalo de Wait for negativo (loop demorou mais que o time step)


# Constantes globais
.eqv INPUT_DATA_ADDR   0xFF200004	# Endere�o onde � armazenado caracteres de entrada
.eqv INPUT_RDY_ADDR    0xFF200000	# Endere�o com a informa��o sobre o estado do buffer de input. 1: pronto, 0: vazio
.eqv INPUT_FINISH      0x077		# Caractere de finaliza��o	

.eqv TIME_STEP         0x032		# Intervalo entre atualiza��es, em milissegundos

.eqv DISPLAY_ADDR      0xFF000000	# Endere�o do display

.data

# Estado do jogo
GAME_SCORE: 	0x00000000
GAME_HISCORE: 	0x00000000
GAME_STAGE: 	0



# Dados do Dig Dug (personagem).
DIGDUG_LIVES: 5

# Coordenadas dos limites da box.
DIGDUG_TOP_X: 255
DIGDUG_TOP_Y: 255
DIGDUG_BOT_X: 255
DIGDUG_BOT_Y: 255

# Velocidade, em pixels. Pode ter valores negativos.
DIGDUG_SPEED_X: 2
DIGDUG_SPEED_Y: 2

# Inimigos

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
.macro LOAD_DATA (%file_l, %label, %size)
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
.macro DRAW_IMG (%address, %offset, %width, %cropw, %croph, %posx, %posy)
	la t0, %address			# Adicionamos ao endere�o de in�cio o offset desejado
	li t1, %offset
	add t0, t0, t1
	
	# Calculamos qual endere�o onde come�ar a desenhar
	li t3, %posy					# Primeiro pegamos a coordenada Y
	li t1, 320					# Multiplicamos pela largura do display para chegarmos na linha certa
	mul t3, t3, t1			
	addi t3, t3, %posx				# Adiciona-se o valor da cordenada X, para chegar na coluna certa
	li t1, DISPLAY_ADDR				# A tudo isso, adicionamos o endere�o onde come�a o buffer de display
	add t3, t3, t1
	
	li t2, %croph
	# t0: endere�o da imagem na mem�ria
	# t1: n�mero de intervalos de 4 pixels, por linha, a desenhar
	# t2: n�mero de linhas a desenhar
	# t3: endere�o do buffer de display a desenhar
START_DRAW:
	beq t2, zero, END_DRAW				# Se o n�mero de linhas a desenhar for zero, o loop acaba
	li t1, %cropw
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

	li t5, %cropw					# Offset na imagem: (largura do arquivo) - (largura do segmento)
	addi t0, t0, %width
	sub t0, t0, t5
	addi t3, t3, 320				# Offset no buffer: (largura do display) - (largura do segmento)
	sub t3, t3, t5
	
	addi t2, t2, -1 				# Uma linha a menos a desenhar
	j START_DRAW
END_DRAW:
	
.end_macro

# Desenha uma imagem armazenada em mem�ria na tela, na posi��o especificada, com transpar�ncia (cor preta, ou rgb 0, 0, 0)
# %address: endere�o da imagem; %offset: onde come�ar a ler; %width: largura da imagem; %cropw: largura do segmento; %croph: altura do segmento
# %posx: coordenada X da tela; %posy: coordenada Y da tela
.macro DRAW_IMG_TR (%address, %offset, %width, %cropw, %croph, %posx, %posy)
	la t0, %address			# Adicionamos ao endere�o de in�cio o offset desejado
	li t1, %offset
	add t0, t0, t1
	
	# Calculamos qual endere�o onde come�ar a desenhar
	li t3, %posy					# Primeiro pegamos a coordenada Y
	li t1, 320					# Multiplicamos pela largura do display para chegarmos na linha certa
	mul t3, t3, t1			
	addi t3, t3, %posx				# Adiciona-se o valor da cordenada X, para chegar na coluna certa
	li t1, DISPLAY_ADDR				# A tudo isso, adicionamos o endere�o onde come�a o buffer de display
	add t3, t3, t1
	
	li t2, %croph
	# t0: endere�o da imagem na mem�ria
	# t1: n�mero de pixels por linha a desenhar
	# t2: n�mero de linhas a desenhar
	# t3: endere�o do buffer de display a desenhar
	# Agora, leremos cada pixel individualmente, com a ajuda de dois loops, um interior ao outro
START_DRAW:
	beq t2, zero, END_DRAW				# Se o n�mero de linhas a desenhar for zero, o loop acaba
	li t1, %cropw
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

	li t5, %cropw					# Offset na imagem: (largura do arquivo) - (largura do segmento)
	addi t0, t0, %width
	sub t0, t0, t5
	addi t3, t3, 320				# Offset no buffer: (largura do display) - (largura do segmento)
	sub t3, t3, t5
	
	addi t2, t2, -1					# Uma linha a menos a desenhar
	j START_DRAW
END_DRAW:
	
.end_macro


# Muda o valor de uma label - Sempre estar ciente do valor m�ximo que pode armazenar
.macro SET_VALUE (%label, %value)
	la t1, %label		# Armazena endere�o da label em t5
	li t2, %value		# Armazena valor em t6
	sw t6, 0(t5)		# Muda o valor no endere�o t5 para o valor t6
.end_macro

.data

# Arquivo de imagem para testes
FILE_TEST: .asciz "digdug_sprtsheet.bin"

IMG_TEST: .space 42504

.text
# Come�o do programa
	li s1, 1
MAIN_LOOP: 
	lw t0, INPUT_DATA_ADDR   	# Termina o loop se recebermos o caractere desejado
	li t1, INPUT_FINISH		# Caractere desejado
	beq t0, t1, END			# Teste
	GET_TIME(s0) 			# Pegamos o tempo no come�o do loop
	
	# Resto do jogo aqui
	
	# Teste de imagens
	# Carregamos o arquivo com sprites
LOAD_SPRITE_DT: beq s1, zero, SPRITE_DT_LOADED
	
	LOAD_DATA(FILE_TEST, IMG_TEST, 42504)

	li s1, 0
SPRITE_DT_LOADED:
	
	# Desenhamos algumas segmentos - Referir-se � defini��o dessa fun��o para detalhes
	# Dig Dug olhando para a esquerda
	DRAW_IMG(IMG_TEST, 4340, 154, 12, 13, 30, 30)
	
	# Pooka olhando para a direita
	DRAW_IMG(IMG_TEST, 23281, 154, 12, 11, 100, 30)
	DRAW_IMG(IMG_TEST, 23281, 154, 12, 11, 100, 60)
	DRAW_IMG(IMG_TEST, 23281, 154, 12, 11, 120, 90)
	DRAW_IMG_TR(IMG_TEST, 23281, 154, 12, 11, 140, 150)
	
	# Fygar olhando para a esquerda
	DRAW_IMG(IMG_TEST, 14940, 154, 12, 12, 160, 160)
	DRAW_IMG(IMG_TEST, 14940, 154, 12, 12, 160, 190)
	DRAW_IMG(IMG_TEST, 14940, 154, 12, 12, 160, 220)
	DRAW_IMG_TR(IMG_TEST, 14940, 154, 12, 12, 190, 160)
	# Rocha
	
	
	
	
WAIT:
	# Calcula quanto tempo esperar at� a pr�xima atualiza��o, printa esse tempo
	GET_TIME(t1)			# Pegamos o tempo no final do loop, ap�s todas as computa��es
	addi s0, s0, TIME_STEP  	# Adicionamos o intervalo que queremos, para decidir o momento da pr�xima atualiza��o
	sub s0, s0, t1			# Subtra�mos o tempo no final do loop do valor anterior para sabermos quanto tempo esperar
	
	mv a0, s0			# Printamos esse valor
	li a7, 1
	ecall
	li a0, 10			# Printamos 'new line', para pular para a pr�xima linha no I/O
	li a7, 11
	ecall
	
	WAIT(s0)
	
	j MAIN_LOOP

END:	li a7, 10			# Termina o programa
	ecall
