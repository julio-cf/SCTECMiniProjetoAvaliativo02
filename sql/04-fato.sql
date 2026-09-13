USE dw_pata_amiga;

-- Limpa a tabela
TRUNCATE TABLE fato_pedido;

INSERT INTO fato_pedido (
    numero_pedido,
    sk_tempo_pedido,
    sk_tempo_entrega,
    sk_loja,
    sk_categoria,
    houve_desconto,
    canal_pedido,
    dt_pedido,
    qt_itens,
    vl_liquido,
    dias_integracao_separacao,
    dias_separacao_nota,
    dias_nota_despacho,
    dias_despacho_entrega,
    dias_total_ate_entrega
)
SELECT 
    p.`NumeroPedido`,
    
    -- Converte data americana (MM/DD/YYYY) para AAAAMMDD numérico
    CAST(DATE_FORMAT(STR_TO_DATE(p.`DtHoraPedido`, '%m/%d/%Y %h:%i %p'), '%Y%m%d') AS SIGNED) AS sk_tempo_pedido,
    
    -- Se vazio, -1. Senão, converte para AAAAMMDD
    CASE 
        WHEN p.`DtEntregaCliente` = '' THEN -1 
        ELSE CAST(DATE_FORMAT(DATE(p.`DtEntregaCliente`), '%Y%m%d') AS SIGNED) 
    END AS sk_tempo_entrega,
    
    
    IFNULL(dl.sk_loja, -1) AS sk_loja,
    IFNULL(dc.sk_categoria, -1) AS sk_categoria,
    
    -- Desconto
    CASE 
        WHEN UPPER(TRIM(p.`HouveDesconto`)) IN ('S', 'SIM', '1', 'X', 'TRUE', 'V') THEN 'Sim'
        WHEN UPPER(TRIM(p.`HouveDesconto`)) IN ('N', 'NAO', '0', 'FALSE', 'F') THEN 'Nao'
        ELSE 'Nao Informado'
    END AS houve_desconto,
    
    -- Canal de Venda
    CASE 
        WHEN UPPER(p.`CanalPedido`) LIKE '%WHATS%' THEN 'WhatsApp'
        WHEN UPPER(p.`CanalPedido`) LIKE '%APP%' THEN 'App'
        WHEN UPPER(p.`CanalPedido`) LIKE '%SITE%' THEN 'Site'
        WHEN UPPER(p.`CanalPedido`) LIKE '%LOJA%' THEN 'Loja Fisica'
        WHEN UPPER(p.`CanalPedido`) LIKE '%TEL%' THEN 'Telefone'
        ELSE 'Nao Informado'
    END AS canal_pedido,
    
    -- Data do pedido
    STR_TO_DATE(p.`DtHoraPedido`, '%m/%d/%Y %h:%i %p') AS dt_pedido,
    
    -- Quantidade de Itens
    CASE 
        WHEN TRIM(p.`QTD.Itens`) IN ('', '-', 'n/d', 'N/I') THEN NULL 
        ELSE CAST(REPLACE(p.`QTD.Itens`, '.', '') AS SIGNED) 
    END AS qt_itens,
    
    -- Valor Líquido
    CASE 
        WHEN TRIM(REPLACE(p.`ValorLiquidoPedido(R$)`, 'R$','')) IN ('', '-') THEN NULL
        WHEN p.`ValorLiquidoPedido(R$)` LIKE '%,%' THEN 
             CAST(REPLACE(REPLACE(REPLACE(REPLACE(p.`ValorLiquidoPedido(R$)`, 'R$', ''), ' ', ''), '.', ''), ',', '.') AS DECIMAL(15,2))
        ELSE CAST(REPLACE(REPLACE(p.`ValorLiquidoPedido(R$)`, 'R$', ''), ' ', '') AS DECIMAL(15,2)) 
    END AS vl_liquido,
    
    -- Cálculos de Tempo: Se o FIM for vazio, não realizou a etapa
    CASE 
        WHEN p.`Dt Separacao Estoque` = '' THEN NULL 
        ELSE DATEDIFF(DATE(p.`Dt Separacao Estoque`), DATE(STR_TO_DATE(p.`DtHoraIntegracaoERP`, '%m/%d/%Y %h:%i %p'))) 
    END AS dias_integracao_separacao,
    
    CASE 
        WHEN p.`DtNotaFiscal` = '' THEN NULL 
        ELSE DATEDIFF(DATE(p.`DtNotaFiscal`), DATE(p.`Dt Separacao Estoque`)) 
    END AS dias_separacao_nota,
    
    CASE 
        WHEN p.`Dt_Despacho_Transportadora` = '' THEN NULL 
        ELSE DATEDIFF(DATE(p.`Dt_Despacho_Transportadora`), DATE(p.`DtNotaFiscal`)) 
    END AS dias_nota_despacho,
    
    CASE 
        WHEN p.`DtEntregaCliente` = '' THEN NULL 
        ELSE DATEDIFF(DATE(p.`DtEntregaCliente`), DATE(p.`Dt_Despacho_Transportadora`)) 
    END AS dias_despacho_entrega,
    
    CASE 
        WHEN p.`DtEntregaCliente` = '' THEN NULL 
        ELSE DATEDIFF(DATE(p.`DtEntregaCliente`), DATE(STR_TO_DATE(p.`DtHoraIntegracaoERP`, '%m/%d/%Y %h:%i %p'))) 
    END AS dias_total_ate_entrega

FROM stg_pedido p
-- LEFT JOIN para Loja
LEFT JOIN dim_loja dl ON dl.chave_loja = UPPER(TRIM(
    CASE 
        WHEN REPLACE(REPLACE(p.`Loja-Nome`, '/SC', ''), '  ', ' ') = 'PATA AMIGA BLUMENAL CENTRO' THEN 'PATA AMIGA BLUMENAU CENTRO'
        WHEN REPLACE(REPLACE(p.`Loja-Nome`, '/SC', ''), '  ', ' ') = 'PATA AMIGA FLORIPA NORTE' THEN 'PATA AMIGA FLORIANOPOLIS NORTE'
        WHEN REPLACE(REPLACE(p.`Loja-Nome`, '/SC', ''), '  ', ' ') = 'PATA AMIGA JGUA DO SUL' THEN 'PATA AMIGA JARAGUA DO SUL'
        ELSE REPLACE(REPLACE(p.`Loja-Nome`, '/SC', ''), '  ', ' ')
    END
))
-- LEFT JOIN para a Categoria baseada na grafia crua
LEFT JOIN dim_categoria dc ON dc.categoria_origem = p.`CategoriaProduto`;