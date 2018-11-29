.include "common.s"

############
# Inimigos #
############
.eqv ENEMY_BS_SPEED     0x0A
.eqv ENEMY_UP	        1
.eqv ENEMY_DOWN	        -1
.eqv ENEMY_LEFT         2
.eqv ENEMY_RIGHT        -2

.eqv EXIT_X	     	0
.eqv EXIT_Y		200

.eqv POOKA_SIZE         68		# Espa�o em bytes ocupado por um Pooka - Sempre lembrar de atualizar ap�s altera��es
.eqv FYGAR_SIZE         0

.eqv ENEMY_DIR_OFFSET   4
.eqv ENEMY_POS_OFFSET   24

.data
# Pooka

POOKA_IN: 		.word 1

POOKA_DIRECTION: 	.word ENEMY_DOWN
POOKA_CYCLE: 		.word 0x00

# Estados poss�veis:
# 0: normal; 1: fantasma; 2, 3, 4: inflado; 5: esmagado
POOKA_STATE: 		.word 0x00

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

POOKA_ROCK_ADDR:	.word 0x00

POOKA_INIT_X:		.word 0x00
POOKA_INTI_Y:		.word 0x00

# Fygar

FYGAR_IN: 		.word 1

FYGAR_SPEED_X: 		.word 2
FYGAR_SPEED_Y: 		.word 2

FYGAR_TOP_X: 		.word 255
FYGAR_TOP_Y: 		.word 255
FYGAR_BOT_X: 		.word 255
FYGAR_BOT_Y: 		.word 255

FYGAR_ROCK_ADDR:	.word 0x00

# Inimigos carregados em mem�ria
CURRENT_ENEMY_ADDR:	.word 0x00
ENEMY_AVAIL_DIR:	.space 16

#ALIGNMENT_BUFFER_00:	.space 2
# Pooka(s) - Espa�o para s� um, por enquanto
.align 2
GAME_ENEMY_COUNT:	.word 0
GAME_POOKA_COUNT:	.word 0 		# Quantidade de pookas remanescentes
GAME_POOKA_BUFFER: 	.space 72


.text

# Carrega um inimigo na mem�ria
# %template: label; %size: eqv; %enemy_buffer: label; %posoffset: eqv; %posx e %posy: registradores
.macro LOAD_ENEMY (%template, %size, %enemy_buffer, %posoffset, %posx, %posy)
	# Adicionamos 1 para o contador de inimigos e 1 para o contador daquele tipo de monstro
	la t0, GAME_ENEMY_COUNT
	lw t1, (t0)
	addi t1, t1, 1
	sw t1, (t0)
	
	la t0, %enemy_buffer
	lw t1, -4(t0)
	addi t1, t1, 1
	sw t1, -4(t0)
	
	# O teste presume que sempre haver� um espa�o vazio, s� precisa encontr�-lo
	TEST_AVAILABILITY:
		lw t1, (t0)
		beq t1, zero, TEST_AVAILABILITY_END
		addi t0, t0, %size
		j TEST_AVAILABILITY
	TEST_AVAILABILITY_END:
	
	# Copia o template para o espa�o
	
	la t1, %template
	li t2, %size
	mv t4, t0					# Armazena o endere�o do come�o do espa�o para depois
	
	LOAD:
		beq t2, zero, LOAD_END
		lb t3, (t1)
		sb t3, (t0)
		addi t0, t0, 1
		addi t1, t1, 1
		addi t2, t2, -1
		j LOAD
	LOAD_END:
	
	# Definir posi��o inicial
	
	li t3, %posoffset
	add t0, t4, t3
	mv t1, %posx
	mv t2, %posy
	
	sw t1, (t0)
	sw t2, 4(t0)
	# Bottom coords
	addi t1, t1, 200
	addi t2, t2, 200
	addi t0, t0, 8
	
	sw t1, (t0)
	sw t2, 4(t0)
.end_macro


# Enemy AI

# Testa colis�o com paredes
# Retorna, em a0, 1: colis�o, 0: sem colis�o
# %game_map: Label
# Usa t0, t1, t5, t6, a0
.macro ENEMY_WALL_COLL (%topx, %topy, %direction)

	mv 	t0, %direction
	
	li	t1, ENEMY_UP
	beq 	t0, t1, DIR_UP
	li	t1, ENEMY_DOWN
	beq	t0, t1, DIR_DOWN
	li	t1, ENEMY_LEFT
	beq	t0, t1, DIR_LEFT
	li	t1, ENEMY_RIGHT
	beq	t0, t1, DIR_RIGHT
	j COLL_DETECT
	
	# Procuramos o pixel a testar no mapa do jogo
	DIR_UP: 	li 	t6, 10
		
			mv 	t0, %topx
			div 	t0, t0, t6
		
			mv 	t1, %topy
			addi	t1, t1, -10
			div	t1, t1, t6
			
			li 	t5, 1
			j FIND_OFFSET
			
	DIR_DOWN:	li 	t6, 10
	
			mv 	t0, %topx
			div	t0, t0, t6
			
			mv	t1, %topy
			addi	t1, t1, 200			# Poss�vel problema aqui
			div	t1, t1, t6
			
			li	t5, 1
			j FIND_OFFSET
	
	DIR_LEFT:	li	t6, 10
	
			mv 	t0, %topx
			addi	t1, t1, -10
			div	t0, t0, t6
		
			mv	t1, %topy
			div	t1, t1, t6
			
			li	t5, 320
			j FIND_OFFSET
			
	DIR_RIGHT:	li	t6, 10
	
			mv	t0, %topx
			addi	t1, t1, 200
			div	t0, t0, t6
			
			mv	t1, %topy
			div	t1, t1, t6
			
			li	t5, 320
			
	
	FIND_OFFSET:	li	t6, 320
			mul 	t1, t1, t6
			add	t0, t0, t1
			la 	t6, GAME_MAP
			add	t6, t0, t6
	
			li	t0, 20				# Se encontrar problemas de desempenho, tentar mudar teste de byte para word
	TEST:  		beq 	t0, zero, NO_COLL
			lb	t1, (t6)
			bne 	t1, zero, COLL_DETECT
			add	t6, t6, t5
			addi	t0, t0, -1
			j TEST
			
	NO_COLL:	li 	a0, 0
			j END
	COLL_DETECT:	li	a0, 1
	END:
.end_macro

# Decide a pr�xima dire��o
# Todos os argumentos s�o labels, exceto o �ltimo
# Usa t0, t1, t2, t3, t4, a0, a1, a2, s9, s10, s11
.macro ENEMY_NORMAL_DIR (%enemy_addr)

	# Clear buffer with available directions first
	la	t0, ENEMY_AVAIL_DIR
	sw	x0, (t0)
	sw	x0, 4(t0)
	sw	x0, 8(t0)
	sw	x0, 12(t0)
	mv	s11, zero
	
	# Testamos se o inimigo est� alinhado com a grade
	loadw(	t0, %enemy_addr)
	addi	t0, t0, ENEMY_POS_OFFSET
	lw	a0, (t0)
	lw	a1, 4(t0)
	IS_ALIGNED(a0, a1)
	beq	a0, zero, TEST_CUR_DIR		# Se n�o estiver alinhado, s� pode voltar para tr�s
	
	# Testamos se h� poss�veis caminhos alternativos
	
	loadw(	t0, %enemy_addr)
	addi	t0, t0, ENEMY_DIR_OFFSET
	lw	t1, (t0)
	li	t2, 2
	rem	t1, t1, t2
	# Considerando as dire��es horizontais como 2 e -2, e as verticais como 1 e -1, podemos saber o sentido
	# por meio do resto da divis�o por 2 
	beq	t1, zero, TEST_VERTICAL

	TEST_HORIZONTAL:
		# Test left
		loadw(	t0, %enemy_addr)
		addi	t0, t0, ENEMY_POS_OFFSET
		lw	t3, (t0)
		lw	t4, 4(t0)
		li	a0, ENEMY_LEFT
		ENEMY_WALL_COLL (t3, t4, a0)
		bne	a0, zero, TEST_RIGHT
		# Adiciona dire��o � lista de dire��es v�lidas
		
		la	t0, ENEMY_AVAIL_DIR
		li	t1, 4
		mul	t1, s11, t1
		add	t0, t0, t1
		li	t1, ENEMY_LEFT
		sw	t1, (t0)
		addi	s11, s11, 1
		
		TEST_RIGHT:
			li 	a0, ENEMY_RIGHT
			ENEMY_WALL_COLL(t3, t4, a0)
			bne	a0, zero, CHOOSE_DIR
			
			la	t0, ENEMY_AVAIL_DIR
			li	t1, 4
			mul	t1, s11, t1
			add	t0, t0, t1
			li	t1, ENEMY_RIGHT
			sw	t1, (t0)
			addi	s11, s11, 1
			j CHOOSE_DIR
	
	TEST_VERTICAL:
		# Test up
		loadw(	t0, %enemy_addr)
		addi	t0, t0, ENEMY_POS_OFFSET
		lw	t3, (t0)
		lw	t4, 4(t0)
		li	a0, 1
		ENEMY_WALL_COLL (t3, t4, a0)
		bne	a0, zero, TEST_DOWN
		
		la 	t0, ENEMY_AVAIL_DIR
		li	t1, 4
		mul	t1, s11, t1
		add	t0, t0, t1
		li	t1, ENEMY_UP
		sw	t1, (t0)
		addi	s11, s11, 1
		
		TEST_DOWN:
			li 	a0, ENEMY_DOWN
			ENEMY_WALL_COLL(t3, t4, a0)
			bne	a0, zero, CHOOSE_DIR
			
			la	t0, ENEMY_AVAIL_DIR
			li	t1, 4
			mul	t1, s11, t1
			add	t0, t0, t1
			li	t1, ENEMY_DOWN
			sw	t1, (t0)
			addi	s11, s11, 1
		 
		 
    CHOOSE_DIR:
		# Se n�o houver caminhos dispon�veis, testamos a dire��o atual somente
	beq	s11, zero, TEST_CUR_DIR
		
	la	t0, GAME_ENEMY_COUNT
	li	t1, 1
	beq	t0, t1, LAST_ENEMY
	# N�o � o �ltimo inimigo, ent�o checamos se est� alinhado com Dig Dug
	loadw(	t0, %enemy_addr)
	addi	t0, t0, ENEMY_POS_OFFSET
	lw	t1, (t0)
	lw	t2, 4(t0)
	
	loadw(	t3, DIGDUG_TOP_X)
	beq	t1, t3, CHASE_DIGDUG_SAME_X
	loadw(	t3, DIGDUG_TOP_Y)
	beq	t2, t3, CHASE_DIGDUG_SAME_Y
	j RANDOM_DIRECTION
	
    CHASE_DIGDUG_SAME_X:
    	loadw(	t3, DIGDUG_TOP_Y)
    	sub	t4, t2, t3
    	bge	t4, zero, CHASE_UP
    	# Chase down
    	li	s10, ENEMY_DOWN
    	j DIR_TEST_IF_VALID
    	CHASE_UP:
    		li	s10, ENEMY_UP
		j DIR_TEST_IF_VALID

    CHASE_DIGDUG_SAME_Y:
    	loadw(	t3, DIGDUG_TOP_X)
    	sub	t4, t1, t3
    	bge	t4, zero, CHASE_LEFT
    	# Chase right
    	li	s10, ENEMY_RIGHT
    	j DIR_TEST_IF_VALID
	CHASE_LEFT:
		li	s10, ENEMY_LEFT
		j DIR_TEST_IF_VALID


    LAST_ENEMY:
    	loadw(	t0, %enemy_addr)
    	addi	t0, t0, ENEMY_POS_OFFSET
    	lw	t1, 4(t0)
    
	li	t2, EXIT_Y
	sub	t3, t1, t2
	bgt	t3, zero, ESCAPE_UP
	# Estamos na altura da sa�da, ent�o o inimigo se move horizontalmente
	# Essa se��o s� funciona se a sa�da for em X: 0, Y: 200, e n�o houver obst�culos
	loadw(	t0, %enemy_addr)
	addi	t0, t0, ENEMY_DIR_OFFSET
	li	t1, ENEMY_LEFT
	sw	t1, (t0)
	j END
	
	ESCAPE_UP:
		li	s10, ENEMY_UP
		j DIR_TEST_IF_VALID


    DIR_TEST_IF_VALID: # Temos s10 = dire��o
		mv	a2,	s10
		loadw(	t0, %enemy_addr)
		addi	t0, t0, ENEMY_POS_OFFSET
		lw	a0, (t0)
		lw	a1, 4(t0)
		ENEMY_WALL_COLL(a0, a1, a2)
		bne	a0, zero, RANDOM_DIRECTION
		# Se n�o houver colis�o, perseguimos
		loadw(	t0, %enemy_addr)
		addi	t0, t0, ENEMY_DIR_OFFSET
		sw	s10, (t0)
		j END
		
		
    RANDOM_DIRECTION: # Escolhemos uma dire��o entre as dispon�veis. Testamos se a dire��o atual e a inversa dela s�o v�lidas.
    	loadw(	t0, %enemy_addr)
    	addi	t0, t0, ENEMY_DIR_OFFSET
    	lw	s10, (t0)
	
	loadw(	t0, %enemy_addr)
	addi	t0, t0, ENEMY_POS_OFFSET
	lw	a0, (t0)
	lw	a1, 4(t0)
	ENEMY_WALL_COLL(a0, a1, s10)
	bne	a0, zero, TEST_OPP_DIR
	
	la	t2, ENEMY_AVAIL_DIR
	li	t1, 4
	mul	t1, s11, t1
	add	t2, t2, t1
	sw	s10, (t2)
	addi	s11, s11, 1
	TEST_OPP_DIR:
		neg 	s10, s10
		lw	a0, (t0)
		lw	a1, 4(t0)
		ENEMY_WALL_COLL(a0, a1, s10)
		bne 	a0, zero, PICK_RNDM_DIR
		
		la	t1, ENEMY_AVAIL_DIR
		li	t1, 4
		mul	t1, s11, t1
		add	t1, t2, t1
		sw	s10, (t2)
		addi	s11, s11, 1
		
	PICK_RNDM_DIR: 			# Geramos um n�mero aleat�rio usando o syscall de tempo
		li	a7, 30
		ecall
		mv	a1, a0
		li	a0, 0
		li	a7, 40
		ecall
		
		addi	s11, s11, -1
		mv	a1, s11
		li	a7, 42
		ecall
		
		la	t0, ENEMY_AVAIL_DIR
		li	t1, 4
		mul	t1, t1, a0
		add	t0, t0, t1
		lw	t3, (t0)
		
		loadw(	t0, %enemy_addr)
		addi	t0, t0, ENEMY_DIR_OFFSET
		sw	t3, (t0)
		j END
	
	# Testa se h� colis�o no caminho atual, se houver, troca para o sentido oposto
    TEST_CUR_DIR:
    	loadw(	t0, %enemy_addr)
    	addi	t0, t0, ENEMY_POS_OFFSET
    	lw	a0, (t0)
    	lw	a1, 4(t0)
    	
    	loadw(	t0, %enemy_addr)
    	addi	t0, t0, ENEMY_DIR_OFFSET
    	lw	a2, (t0)
    	
    	ENEMY_WALL_COLL (a0, a1, a2)
    	beq	a0, zero, END
    	# N�o funcionar� se o sentido oposto n�o for o sentido atual negativado
    	loadw(	t0, %enemy_addr)
    	addi	t0, t0, ENEMY_DIR_OFFSET
    	lw	t1, (t0)
    	neg	t1, t1
    	sw	t1, (t0)
    
    END:
.end_macro

# Atualiza posi��o do inimigo, caso esteja em estado normal
# Usa t0, t1, t2, t3, a0, a1, a2, a3
.macro ENEMY_UPDATE_POSITION (%enemy_addr)
	# Testar se est� normal ou fantasma, talvez?
	
	# Guardamos a posi��o anterior primeiro
	loadw(	t0, %enemy_addr)
	addi	t0, t0, ENEMY_POS_OFFSET		# N�o alterar t0 a partir de agora
	lw	a0, (t0)
	lw	a1, 4(t0)
	sw	a0, 16(t0)				# N�o alterar a0 e a1
	sw	a1, 20(t0)
	addi	a2, a0, 200
	addi	a3, a1, 200
	sw	a2, 24(t0)
	sw	a3, 28(t0)
	
	# Escolhemos a dire��o
	
	loadw(	t1, %enemy_addr)
	addi	t1, t1, ENEMY_DIR_OFFSET
	lw	t2, (t1)
	
	li	t3, ENEMY_UP
	beq	t2, t3, ENEMY_MOVE_UP
	li	t3, ENEMY_DOWN
	beq	t2, t3, ENEMY_MOVE_DOWN
	li	t3, ENEMY_LEFT
	beq	t2, t3, ENEMY_MOVE_LEFT
	
	# a0: POS_X, a1: POS_Y
    	# ENEMY_MOVE_RIGHT
		addi	a2, a0, ENEMY_BS_SPEED
		sw	a2, (t0)
		addi	a2, a2, 200
		sw	a2, 8(t0)
		j END
   	 ENEMY_MOVE_UP:
		li	a2, ENEMY_BS_SPEED
		neg	a2, a2
		add	a2, a1, a2
		sw	a2, 4(t0)
		addi	a2, a2, 200
		sw	a2, 12(t0)
		j END
	ENEMY_MOVE_DOWN:
		addi	a2, a1, ENEMY_BS_SPEED
		sw	a2, 4(t0)
		addi	a2, a2, 200
		sw	a2, 12(t0)
		j END
	ENEMY_MOVE_LEFT:
		li	a2, ENEMY_BS_SPEED
		neg	a2, a2
		add	a2, a0, a2
		sw	a2, (t0)
		addi	a2, a2, 200
		sw	a2, 8(t0)
		j END
	
    END:
.end_macro

.macro ENEMY_ACTION (%enemy_addr)
	# Julgar o que fazer baseado no estado do inimgo.
	
	
	# Estado normal
	# To-do:
	# - Testar se transforma em fantasma
	#
	ENEMY_NORMAL_DIR(%enemy_addr)
	ENEMY_UPDATE_POSITION(%enemy_addr)
.end_macro
