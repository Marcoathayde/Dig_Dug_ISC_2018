.eqv	TRANSP		0x0C7

#################################
# Dados do Dig Dug (personagem) #
#################################
.data

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

DIGDUG_SPRT_SHEET_PATH: .asciz "bin/digdug_sprites.bin"
DIGDUG_SPRT_SHEET:	.space 18000
.text

# Apaga parte do background na posição de Dig Dug
# Usa t0, t1, t2, t3, t4, a0, a1, a3, a4, a5
.macro DIGDUG_DIGS ()

	# Apaga seção do mapa de jogo

	loadw(	a0, DIGDUG_TOP_Y)
	loadw(	a1, DIGDUG_TOP_X)

	li 	t0, 10
	div 	a0, a0, t0
	div 	a1, a1, t0
	addi 	a0, a0, 1
	addi 	a1, a1, 1
	li 	a3, 18
	li 	a4, 18
	la 	a5, GAME_MAP
	WRITE_TO_BUFFER(GAP_DATA, 18, zero, a3, a4, a0, a1, a5)
	
	loadw(	t0, DIGDUG_TOP_X)
	loadw(	t1, DIGDUG_TOP_Y)
	loadw(	t2, DIGDUG_DIRECTION)
	
	beq	t2, zero, DIG_UP
	li	t3, 1
	beq	t2, t3,	DIG_DOWN
	li	t3, 2
	beq	t2, t3, DIG_LEFT
	
    # DIG_RIGHT:
    	addi	t0, t0, 100
    	li	t2, 20
    	li	s10, 10
    	la	a0, BG_VLAYER_BUFFER
    	j OFFSET
    	
    DIG_LEFT:
    	li	t2, 20
    	li	s10, 10
    	la	a0, BG_VLAYER_BUFFER
    	j OFFSET
    	
    DIG_UP:
    	li	t2, 10
    	li	s10, 20
    	la	a0, BG_HLAYER_BUFFER
    	j OFFSET
    	
    DIG_DOWN:
    	addi	t0, t0, 100
    	li	t2, 10
    	li	s10, 20
    	la	a0, BG_HLAYER_BUFFER
    	
    	# Calcular offset: Pos Y * 320 + Pos X
    OFFSET:
    	li	t4, 10
    	div	t0, t0, t4
    	div	t1, t1, t4
    	
    	li	t4, 320
    	mul	t1, t1, t4
    	add	t0, t1, t0
    	
    	la	a1, BG_DLAYER_BUFFER
    	add	a1, a1, t0
    	add	a0, a0, t0
    	
    	# t2: número de linhas
    	# t3: número de colunas
    	# a0: Buffer a ser apagado: ou horizontal, ou vertical
    	# a1: Buffer da terra
    	
    OUTER:
    	beq	t2, zero, END_OUTER
    	mv	t3, s10
    		INNER:
    			beq	t3, zero, END_INNER
    			
    			li	t4, TRANSPARENT
    			sb	t4, (a0)
    			sb	t4, (a1)
    			
    			addi	a0, a0, 1
    			addi	a1, a1, 1
    			
    			addi	t3, t3, -1
    			j INNER
		END_INNER:
	addi	a0, a0, 320
	addi	a1, a1, 320
	sub	a0, a0, s10
	sub	a1, a1, s10
	
	addi	t2, t2, -1
	j OUTER
    END_OUTER:

.end_macro
