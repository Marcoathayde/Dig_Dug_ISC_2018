.eqv	TRANSP		0x0C7

#################################
# Dados do Dig Dug (personagem) #
#################################
.data

DIGDUG_DIRECTION: 	.word 0x02	# 0: cima; 1: baixo; 2: esquerda; 3: direita
DIGDUG_STATE: 		.word 0x00	# 0: Não cavando; 1: Cavando; 2: Jogando mangueira; 3: Enchendo 
DIGDUG_MOVED:		.word 0x00
DIGDUG_CYCLE:		.word 0x01

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

	loadw(	a0, DIGDUG_TOP_X)
	loadw(	a1, DIGDUG_TOP_Y)

	li 	t0, 10
	div 	a0, a0, t0
	div 	a1, a1, t0
	addi 	a0, a0, 1
	addi 	a1, a1, 1
	li 	a3, 18
	li 	a4, 18
	la 	a5, GAME_MAP
	WRITE_TO_BUFFER(GAP_DATA, 18, zero, a3, a4, a0, a1, a5)
	# Retorna booleana DIGDUG_DIGGING em s11
	sw	s11, DIGDUG_STATE, t0
	
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
    	addi	t1, t1, 100
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
    			
    			li	t4, TRANSP
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

# Analisa estado atual de Dig Dug, escolha sprite correto, e atualiza contador de ciclo de animação
# Retorna em a0 o offset, em a1 e a2 as dimensões de corte (a1: width)
# Usa t0, t1, s10, s11, a0, a1, a2
.macro DIGDUG_SPRITE_PICK ()


	loadw(	t0, DIGDUG_STATE)
	loadw(	s10, DIGDUG_DIRECTION)
	loadw(	s11, DIGDUG_CYCLE)
	
	beq	t0, zero, WALKING
	li	t1, 1
	beq	t0, t1, DIGGING

    # Alerta: muitas magic constants
    # Necessário olhar o arquivo de sprite para tirar os valores
    
    WALKING:
    	
    	# Pegamos a direção e testamos
  
    	beq	s10, zero, WALK_UP
    	li	t0, 1
    	beq	s10, t0, WALK_DOWN
    	li	t0, 2
    	beq	s10, t0, WALK_LEFT
    	
    # WALK_RIGHT:
    	li	t0, 3240
    	add	a0, zero, t0
    	j CYCLE
    	
    WALK_LEFT:
    	li	t0, 2592
    	add	a0, zero, t0
    	j CYCLE
    	
    WALK_UP:
    	li	t0, 4536
    	add	a0, zero, t0
    	j CYCLE
    	
    WALK_DOWN:
    	li	t0, 3888
    	add	a0, zero, t0
    	j CYCLE
    
    ### CAVANDO ####
    DIGGING:
    	
    	add	a0, zero, zero
    	# Pegamos a direção e testamos
  
    	beq	s10, zero, DIG_UP
    	li	t0, 1
    	beq	s10, t0, DIG_DOWN
    	li	t0, 2
    	beq	s10, t0, DIG_LEFT
    	
    	# DIG_RIGHT:
    		addi	a0, a0, 648
    		j CYCLE
    	
    	DIG_LEFT:
    		addi	a0, a0, 0
    		j CYCLE
    
    	DIG_UP:
    		addi	a0, a0, 1944
    		j CYCLE
    
    	DIG_DOWN:
    		addi	a0, a0, 1296
    	  	
    	
    	# Como Dig Dug só tem dois sprites por animação, só tem 2 ciclos
    	# Achamos o offset X multiplicando o ciclo pelo tamanho do sprite
    	CYCLE: 
    		# Testamos primeiro se Dig Dug está se movimentando. Se não estiver, não fazemos nada
    		loadw(	t0, DIGDUG_SPEED_X)
    		loadw(	t1, DIGDUG_SPEED_Y)
    	
    		add	t0, t0, t1
    		beq	t0, zero, END
    	
    		# Para que a animação só seja atualizada a cada 2 frames
    		mv	t1, s11
    		li	t2, 2
    		#div	t1, t1, t2
    		
    		li	t0, 18
    		mul	t0, t0, t1
    		add	a0, a0, t0
    		
    		# Usamos função modulo para retornar o contador de ciclos para 0, se alcançar 4
    		li	t0, 2
    		addi	s11, s11, 1
    		rem	s11, s11, t0
    		
    		sw	s11, DIGDUG_CYCLE, t0
    		
    		
    		j END
    
    END:
    	li	a1, 18
    	li	a2, 18
.end_macro
