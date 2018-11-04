# Lembrar de colocar o valor m�ximo em cada v�riavel.
# Nunca usar t5 e t6. Registradores reservados para macros.

# TO-DO List
# - Calcular quanto espa�o cada inimigo usa.
# - Com isso, definir espa�o m�ximo a ser alocado para os inimigos em cada fase.
# - Definir o que fazer quando o intervalo de Wait for negativo (loop demorou mais que o time step)


# Constantes globais
.eqv INPUT_DATA_ADD   0xFF200004	# Endere�o onde � armazenado caracteres de entrada
.eqv INPUT_RDY_ADD    0xFF200000	# Endere�o com a informa��o sobre o estado do buffer de input. 1: pronto, 0: vazio
.eqv INPUT_FINISH     0x077		# Caractere de finaliza��o	
.eqv TIME_STEP        0x021		# Intervalo entre atualiza��es, em milissegundos

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

# Acha o tempo atual e armazena o valor em %var
.macro GET_TIME (%reg)
	li a7, 30
	ecall
	mv %reg, a0
.end_macro

# Pausa o programa pelo tempo em %var, em milissegundos
.macro WAIT (%reg)
	mv a0, %reg
	li a7, 32
	ecall
.end_macro
	
# Muda o valor de uma label - Sempre estar ciente do valor m�ximo que pode armazenar
.macro SET_VALUE (%label, %value)
	la t5, %label		# Armazena endere�o da label em t5
	li t6, %value		# Armazena valor em t6
	sw t6, 0(t5)		# Muda o valor no endere�o t5 para o valor t6
.end_macro

# Come�o do programa

MAIN_LOOP: 
	lw t0, INPUT_DATA_ADD   	# Termina o loop se recebermos o caractere desejado
	li t1, INPUT_FINISH		# Caractere desejado
	beq t0, t1, END
	GET_TIME(t0) 			# Pegamos o tempo no come�o do loop
	# A partir de agora, n�o podemos usar t0
	
	# Resto do jogo aqui
	







	# Calcula quanto tempo esperar at� a pr�xima atualiza��o, printa esse tempo
	GET_TIME(t1)			# Pegamos o tempo no final do loop, ap�s todas as computa��es
	addi t0, t0, TIME_STEP  	# Adicionamos o intervalo que queremos, para decidir o momento da pr�xima atualiza��o
	sub t0, t0, t1			# Subtra�mos o tempo no final do loop do valor anterior para sabermos quanto tempo esperar
	
	mv a0, t0			# Printamos esse valor
	li a7, 1
	ecall
	li a0, 10			# Printamos 'new line', para pular para a pr�xima linha no I/O
	li a7, 11
	ecall
	
	WAIT(t0)
	
	j MAIN_LOOP

END:	li a7, 10			# Termina o programa
	ecall
