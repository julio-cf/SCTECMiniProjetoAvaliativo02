USE dw_pata_amiga;

-- =====================================================================================
--  P1 - ONDE ESTA O GARGALO DO PROCESSO DE ENTREGA?
-- =====================================================================================
--  Media (AVG) dos quatro intervalos ja calculados na carga, agrupada por porte
--  de loja. AVG ignora NULL - por isso a etapa nao cumprida foi gravada como NULL.
--  dias_total_ate_entrega e o processo inteiro, nao um dos quatro intervalos.

-- >>> ESCREVA AQUI a consulta da P1

-- Calcula a média geral
SELECT 
    'TOTAL DA REDE' AS porte_loja,
    ROUND(AVG(dias_total_ate_entrega), 2) AS total_dias_ate_entrega,
    ROUND(AVG(dias_integracao_separacao), 2) AS integracao_separacao,
    ROUND(AVG(dias_separacao_nota), 2) AS separacao_nota,
    ROUND(AVG(dias_nota_despacho), 2) AS nota_despacho,
    ROUND(AVG(dias_despacho_entrega), 2) AS despacho_entrega
FROM fato_pedido;


-- Calcula a média por porte de loja
SELECT 
    dl.porte AS porte_loja,
    ROUND(AVG(f.dias_total_ate_entrega), 2) AS total_dias_ate_entrega,
    ROUND(AVG(f.dias_integracao_separacao), 2) AS integracao_separacao,
    ROUND(AVG(f.dias_separacao_nota), 2) AS separacao_nota,
    ROUND(AVG(f.dias_nota_despacho), 2) AS nota_despacho,
    ROUND(AVG(f.dias_despacho_entrega), 2) AS despacho_entrega
FROM fato_pedido f
JOIN dim_loja dl ON f.sk_loja = dl.sk_loja
GROUP BY dl.porte
ORDER BY total_dias_ate_entrega DESC;


-- =====================================================================================
--  P2 - QUAL CATEGORIA CONCENTRA O FATURAMENTO?
-- =====================================================================================
--  Esta e a pergunta que paga a dim_categoria. Agrupe pelo nome_categoria
--  PADRONIZADO (nunca pela grafia crua). O percentual do total usa uma
--  subconsulta com o faturamento da rede como denominador.

-- >>> ESCREVA AQUI a consulta da P2

-- Categoria geral e %
SELECT 
    dc.nome_categoria,
    ROUND(SUM(f.vl_liquido), 2) AS faturamento,
    ROUND((SUM(f.vl_liquido) / (SELECT SUM(vl_liquido) FROM fato_pedido)) * 100, 2) AS percentual_total
FROM fato_pedido f
JOIN dim_categoria dc ON f.sk_categoria = dc.sk_categoria
GROUP BY dc.nome_categoria
ORDER BY faturamento DESC;

-- Categoria campeã por porte de loja
SELECT 
    dl.porte,
    dc.nome_categoria,
    ROUND(SUM(f.vl_liquido), 2) AS faturamento
FROM fato_pedido f
JOIN dim_loja dl ON f.sk_loja = dl.sk_loja
JOIN dim_categoria dc ON f.sk_categoria = dc.sk_categoria
GROUP BY dl.porte, dc.nome_categoria
ORDER BY dl.porte, faturamento DESC;


-- =====================================================================================
--  P3 - O DESCONTO FUNCIONA IGUAL EM TODO CANAL?
-- =====================================================================================
--  Aqui NAO ha JOIN: desconto e canal foram padronizados na carga e moram na
--  propria fato. Compare o TICKET MEDIO com e sem desconto DENTRO de cada canal.
--  Confira se o WhatsApp aparece - se nao, o CASE do arquivo 04 testou APP antes
--  de WHATS.

-- >>> ESCREVA AQUI a consulta da P3

SELECT 
    canal_pedido,
    ROUND(AVG(CASE WHEN houve_desconto = 'Sim' THEN vl_liquido END), 2) AS ticket_medio_COM_desconto,
    ROUND(AVG(CASE WHEN houve_desconto = 'Nao' THEN vl_liquido END), 2) AS ticket_medio_SEM_desconto,
    ROUND(SUM(vl_liquido), 2) AS faturamento_total_canal,
    ROUND((SUM(vl_liquido) / (SELECT SUM(vl_liquido) FROM fato_pedido)) * 100, 2) AS rep_percentual
FROM fato_pedido
GROUP BY canal_pedido
ORDER BY faturamento_total_canal DESC;


-- =====================================================================================
--  P4 - QUAL PRACA DE ATENDIMENTO CONCENTRA O FATURAMENTO?
-- =====================================================================================
--  Esta e a pergunta que paga a dim_praca e a ponte.
--  Caminho: fato_pedido -> dim_loja -> bridge_loja_praca -> dim_praca (a ponte
--  entra pelo cod_loja). O JOIN com a ponte DUPLICA a linha do pedido, uma por
--  praca - isso esta certo. Multiplique por b.fator_publico para o faturamento
--  nao ser contado duas vezes.

-- >>> ESCREVA AQUI a consulta da P4

SELECT 
    dp.nome_praca,
    dp.domicilios_com_pet,
    ROUND(SUM(f.vl_liquido * b.fator_publico), 2) AS faturamento_rateado
FROM fato_pedido f
JOIN dim_loja dl ON f.sk_loja = dl.sk_loja
JOIN bridge_loja_praca b ON dl.cod_loja = b.cod_loja
JOIN dim_praca dp ON b.sk_praca = dp.sk_praca
GROUP BY dp.nome_praca, dp.domicilios_com_pet
ORDER BY faturamento_rateado DESC;


-- =====================================================================================
--  P5 - ONDE ABRIR A PROXIMA LOJA, E O QUE OS DADOS NAO PERMITEM AFIRMAR?
-- =====================================================================================
--  (a) Ranqueie as lojas por itens POR MIL HABITANTES (numerador na fato,
--      denominador na dimensao), calculado AQUI na consulta - nunca gravado
--      pronto. Cruze com o tempo medio de entrega.
--  (b) Mostre o faturamento por faixa de franquia e explique por que ele NAO
--      responde "quanto veio de lojas que JA ERAM Ouro na data do pedido": o
--      cadastro so tem a foto de hoje.
--  (c) Meca o que ficou de fora: pedidos sem loja, entregas nao concluidas,
--      itens e valores em branco.

-- >>> ESCREVA AQUI as consultas da P5

-- a)
SELECT 
    dl.nome_loja,
    dl.cidade,
    SUM(f.qt_itens) AS itens_absolutos,
    ROUND(SUM(f.qt_itens) / (dl.populacao_cidade / 1000), 2) AS itens_por_mil_habitantes,
    ROUND(AVG(f.dias_total_ate_entrega), 2) AS tempo_medio_entrega_dias
FROM fato_pedido f
JOIN dim_loja dl ON f.sk_loja = dl.sk_loja
WHERE dl.sk_loja <> -1
GROUP BY dl.nome_loja, dl.cidade, dl.populacao_cidade
ORDER BY itens_por_mil_habitantes DESC;

-- b)
SELECT 
    dl.faixa_franquia,
    ROUND(SUM(f.vl_liquido), 2) AS faturamento
FROM fato_pedido f
JOIN dim_loja dl ON f.sk_loja = dl.sk_loja
GROUP BY dl.faixa_franquia
ORDER BY faturamento DESC;

-- c)
SELECT 
    SUM(CASE WHEN sk_loja = -1 THEN 1 ELSE 0 END) AS pedidos_sem_loja,
    SUM(CASE WHEN sk_tempo_entrega = -1 THEN 1 ELSE 0 END) AS entregas_nao_concluidas,
    SUM(CASE WHEN qt_itens IS NULL THEN 1 ELSE 0 END) AS itens_em_branco,
    SUM(CASE WHEN vl_liquido IS NULL THEN 1 ELSE 0 END) AS valores_em_branco
FROM fato_pedido;
