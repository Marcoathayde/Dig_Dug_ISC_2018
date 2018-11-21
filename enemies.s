.include "common.s"

############
# Inimigos #
############
.eqv ENEMY_UP	       1
.eqv ENEMY_DOWN	       -1
.eqv ENEMY_LEFT        2
.eqv ENEMY_RIGHT       -2


.eqv POOKA_SIZE        64		# Espaço em bytes ocupado por um Pooka - Sempre lembrar de atualizar após alterações
.eqv FYGAR_SIZE        0

.eqv ENEMY_DIR_OFFSET  4
.eqv ENEMY_POS_OFFSET  24

.data
# Pooka

POOKA_IN: 		.word 1

POOKA_DIRECTION: 	.word 0x00
POOKA_CYCLE: 		.word 0x00

# Estados possíveis:
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

POOKA_ROCK_X:		.word 0x00
POOKA_ROCK_Y:		.word 0x00

# Fygar

FYGAR_IN: 		.word 1

FYGAR_SPEED_X: 		.word 2
FYGAR_SPEED_Y: 		.word 2

FYGAR_TOP_X: 		.word 255
FYGAR_TOP_Y: 		.word 255
FYGAR_BOT_X: 		.word 255
FYGAR_BOT_Y: 		.word 255



CURRENT_ENEMY_ADDR:	.word 0x00
#ALIGNMENT_BUFFER_00:	.space 2
# Pooka(s) - Espaço para só um, por enquanto
.align 2
GAME_POOKA_COUNT:	.word 0 		# Quantidade de pookas remanescentes
GAME_POOKA_BUFFER: 	.space 64


.text

# Carrega um inimigo na memória
# %template: label; %size: eqv; %enemy_buffer: label; %posoffset: eqv; %posx e %posy: registradores
.macro LOAD_ENEMY (%template, %size, %enemy_buffer, %posoffset, %posx, %posy)
	la t0, %enemy_buffer
	# Adicionamos 1 para o contador de inimigos
	lw t1, -4(t0)
	addi t1, t1, 1
	sw t1, -4(t0)
	
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
	
	LOAD:
		beq t2, zero, LOAD_END
		lb t3, (t1)
		sb t3, (t0)
		addi t0, t0, 1
		addi t1, t1, 1
		addi t2, t2, -1
		j LOAD
	LOAD_END:
	
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


# Enemy AI

# Testa colisão com paredes
# Retorna, em a0, 1: colisão, 0: sem colisão
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
	j COLL_DETECTED
	
	# Procuramos o pixel a testar no mapa do jogo
	DIR_UP: 	li 	t6, 10
		
			mv 	t0, %topx
			div 	t0, t0, t6
		
			mv 	t1, %topy
			addi	t1, t1, -10
			div	t1, t1, t6
			
			mv 	t5, 1
			j FIND_OFFSET
			
	DIR_DOWN:	li 	t6, 10
	
			mv 	t0, %topx
			div	t0, t0, t6
			
			mv	t1, %topy
			addi	t1, t1, 200			# Possível problema aqui
			div	t1, t1, t6
			
			mv	t5, 1
			j FIND_OFFSET
	
	DIR_LEFT:	li	t6, 10
	
			mv 	t0, %topx
			addi	t1, t1, -10
			div	t0, t0, t6
		
			mv	t1, %topy
			div	t1, t1, t6
			
			mv	t5, 320
			j FIND_OFFSET
			
	DIR_RIGHT:	li	t6, 10
	
			mv	t0, %topx
			addi	t1, t1, 200
			div	t0, t0, t6
			
			mv	t1, %topy
			div	t1, t1, t6
			
			mv	t5, 320
			
	
	FIND_OFFSET:	li	t6, 320
			mul 	t1, t1, t6
			add	t0, t0, t1
			la 	t6, GAME_MAP
			add	t6, t0, t6
	
			li	t0, 20				# Se encontrar problemas de desempenho, tentar mudar teste de byte para word
	TEST:  		beq 	t0, zero, NO_COLL
			lb	t1, (t6)
			bne 	t1, zero, COLL_DETECTED
			add	t6, t6, t5
			addi	t0, t0, -1
			j TEST
			
	NO_COLL:	li 	a0, 0
			j END
	COLL_DETECT:	li	a0, 1
	END:
.end_macro

# Decide a próxima velocidade
# Todos os argumentos são labels, exceto o último
.macro ENEMY_NORMAL_WALK (%enemy_addr, %dd_adr, %enemy_ctr)

	# Testamos se o inimigo está alinhado com a grade
	la	t0, %enemy_addr
	addi	t0, t0, ENEMY_POS_OFFSET
	lw	a0, (t0)
	lw	a1, 4(t0)
	IS_ALIGNED(a0, a1)
	beq	a0, zero, TEST_CUR_DIR		# Se não estiver alinhado, só pode voltar para trás
	
	
	
	
	# Testa se há colisão no caminho atual, se houver, troca para o sentido oposto
    TEST_CUR_DIR:
    	la	t0, %enemy_addr
    	addi	t0, t0, ENEMY_POS_OFFSET
    	lw	a0, (t0)
    	lw	a1, 4(t0)
    	
    	la	t0, %enemy_addr
    	addi	t0, t0, ENEMY_DIR_OFFSET
    	lw	a2, (t0)
    	
    	ENEMY_WALL_COLL (a0, a1, a2)
    	beq	a0, zero, END
    	# Não funcionará se o sentido oposto não for o sentido atual negativado
    	la	t0, %enemy_addr
    	addi	t0, t0, ENEMY_DIR_OFFSET
    	lw	t1, (t0)
    	neg	t1, t1
    	sw	t1, (t0)
    
    END:
.end_macro

.macro ENEMY_PHASE()



.end_macro