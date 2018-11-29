# Constantes globais
.eqv INPUT_DATA_ADDR   0xFF200004	# Endere�o onde � armazenado caracteres de entrada
.eqv INPUT_RDY_ADDR    0xFF200000	# Endere�o com a informa��o sobre o estado do buffer de input. 1: pronto, 0: vazio	

.eqv TIME_STEP         0x030		# Intervalo entre atualiza��es, em milissegundos
.eqv DISPLAY_ADDR      0xFF000000	# Endere�o do display
.eqv DIGDUG_BS_SPEED   0x0A		# Velocidade de Dig Dug (No momento, precisa ser menor que 10, sen�o quebra o jogo
# Controles
.eqv GAME_UP_KEY       0x077		# w
.eqv GAME_DW_KEY       0x073		# s	
.eqv GAME_LF_KEY       0x061		# a
.eqv GAME_RT_KEY       0x064		# d
.eqv GAME_ATK_KEY      0x06C		# l

# Informa��o de buffer do jogo

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


# Dados de imagem
SPRITE_SHEET_PATH: 	.asciz "bin/digdug_sprtsheet.bin"
SPRITE_SHEET_BUFFER: 	.space 42504

.text
# Fun��es
# Usa um registrador para fazer um pulo sem restri��es
.macro jump (%reg, %label)
	la	%reg, %label
	jalr	zero, %reg, 0
.end_macro
# Usa um registrador para carregar dado armazenado no endere�o da label, sem restri��es
.macro loadw (%reg, %label)
	la	%reg, %label
	lw	%reg, (%reg)
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
	bgez a0, NORMAL_TIME_STEP	# Caso o loop demore demais, n�o esperamos nada
	li a0, 0		
NORMAL_TIME_STEP:
	li a7, 32
	ecall
.end_macro

# Abre, carrega um arquivo em mem�ria, na label dada, fecha o arquivo. � preciso ter certeza que o espa�o necess�rio j� foi reservado
.macro LOAD_FILE (%file_l, %buffer, %size)
	la a0, %file_l			# Abrimos o arquivo usando o caminho armazenado na label
	li a1, 0
	li a7, 1024
	ecall				# Descriptor � colocado em a0, que iremos utilizar a seguir
	mv t0, a0			# Descriptor � armazenado t0, sen�o ser� perdido na pr�xima chamada
	
	la a1, %buffer			# Endere�o onde os dados ser�o armazenados
	li a2, %size			# Tamanho a armazenar
	li a7, 63
	ecall
	
	mv a0, t0			# Fechamos o arquivo
	li a7, 57
	ecall
.end_macro

# Carrega o caminho apontado pelo ponteiro
.macro LOAD_FILE_PTR (%ptr, %buffer, %size)
	lw a0, %ptr
	li a1, 0
	li a7, 1024
	ecall
	mv t0, a0
	
	la a1, %buffer
	li a2, %size
	li a7, 63
	ecall
	
	mv a0, t0
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
	srli t1, t1, 1
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
.macro WRITE_TO_BUFFER (%address, %width, %offset, %cropw, %croph, %posx, %posy, %map_addr)
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

.macro IS_ALIGNED (%posx, %posy)
		# Checamos se � uma posi��o v�lida para mudan�a de dire��o - X e Y precisam ser m�ltiplos de 20
		mv t0, %posx
		mv t1, %posy
		li t2, 200				# Testamos se a posi��o atual se alinha com a grade. Adiciona-se 200 para o caso de coordenada igual a zero
		li t3, 10				
		add t0, t0, t2
		add t1, t1, t2
		div t0, t0, t3				# Divide-se por dez para conseguir coordenada em rela��o ao display 320x240
		div t1, t1, t3
		li t2, 20
		rem t0, t0, t2				# Testamos se as coordenadas s�o m�ltiplas de 20
		rem t1, t1, t2
		bne t0, zero, NOT_ALIGNED
		bne t1, zero, NOT_ALIGNED
		# Alinhado
		li a0, 1
		j END
    NOT_ALIGNED: li a0, 0
    END:
.end_macro
