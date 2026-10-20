"""Integracao 20/10: gera data/npcs/porto_velho.json (elenco da Bolorina + lojas/servicos do Claude)
a partir de data/npcs/porto_velho_provisorio.json (roster original do Claude). Uso: python tools/integracao_elenco.py"""
import json
H={n['id']:n for n in json.load(open('data/npcs/porto_velho_provisorio.json',encoding='utf-8'))['npcs']}
# papel do Claude -> morador da Bolorina (id, nome, papel exibido, falas de balcao PROPOSTA)
MAP=[
 ("helena","ferreiro","Gaspar Bigorna","ferreiro · Ferraria do Porto",["Bigorna quente, conversa curta. Minério e carvão viram lingote; lingote e ouro viram peça.","Se a peça sair torta, a culpa é do martelo. O martelo é meu, mas a culpa é dele."]),
 ("mira","mira","Mira","herbalista · Botica da Mira",H['mira']['falas']),
 ("caio","estalajadeira","Dona Rosalva","estalajadeira · Estalagem da Lanterna",["Cama quente, sopa de peixe e boatos frescos. Os boatos são de graça; a sopa, não.","Ontem um viajante pagou com uma moeda de 3021. Aceitei, claro."]),
 ("bruna","guardia","Brida Ferrolho","guardiã · Posto da Guarda",["O mural de pedidos não se lê sozinho. Quer uma missão?","Se vir um orc de gravata, não ria. Ele é diplomata."]),
 ("marina","capitao","Capitão Bartolomeu Nuvem","capitão do dirigível Andorinha",["A Andorinha sai quando você quiser. Escolha o destino no mapa.","Já fomos à Estação três vezes. Voltamos ontem. Partimos amanhã."]),
 ("ozorio","arquimago","Ozório Pêndulo","arquimago · Torre Torta",H['ozorio']['falas']),
 ("bartolomeu","sineiro","Mestre Anselmo","sineiro · Torre do Sino",H['bartolomeu']['falas']),
 ("rosa","jardineira","Dona Iolanda","horticultora · Celeiro das Sementes",H['rosa']['falas']),
 ("armando","mercador_praca","Mercador da Praça","mercador · barracas da praça",["Compro e vendo de tudo! Sementes, corda, sal... e pago bem pelo que você trouxer.","Metade do preço é justo. A outra metade é saudade."]),
 ("gaspar","minerador_aposentado","Seu Tião Lamparina","mineiro aposentado · Elevador do Tião",["Picareta, lanterna e carvão. E conselho de graça, que é o que sobra a um mineiro aposentado.","Nas Minas da Cinza, prata tumular só sai com picareta de ferro."]),
 ("nina","crianca_praca","Pipo","mensageiro da praça",["Tenho uma carta para entregar! Me ajuda?","Se a carta chegar antes de ser escrita, ainda vale."]),
]
POS={"minerador_aposentado":[-25.5,-12.0]}
NOVOS={"otavio":[-6,12.5],"lurdes":[26,10],"cinira":[22,9],"tobias":[26,2],"severino":[-8,25],"frei_ze":[-24,8],"tempora":[24,-24],"kiko":[-26,24],"fagulha":[52,5]}
out=[]
for hid,mid,nome,papel,falas in MAP:
    h=H[hid]
    out.append({"id":mid,"morador":mid,"nome":nome,"papel":papel,"loja":h['loja'],"retrato":"res://art/ui/retratos/%s.png"%mid,
       "dialogo":"res://dialogos/%s.dialogue"%mid,"falas":falas,"pos":POS.get(mid,h['pos']),"papel_do_claude":"%s (%s)"%(h['nome'],h['papel']),
       "origem":"elenco da Bolorina"})
for hid,pos in NOVOS.items():
    h=dict(H[hid]); h['pos']=pos; h['origem']="morador novo do Claude (PROPOSTA)"; h['retrato']="res://art/ui/retratos/%s.png"%hid
    h.pop('dialogo',None); h.pop('morador_vila',None)
    if hid=="tobias":
        h['falas']=["Mapas novos liberam a viagem para outras partes da ilha.","Desenhei o mapa da Estação antes de ela cair. Ou depois. Depende de quem pergunta."]
        h['nota']="Mesmo nome do Tobias do Ermo (lobisomem) do elenco da Bolorina e do Tobias guia de trilhas da Vila original. PROPOSTA: decidir se são a mesma pessoa."
    if hid=="fagulha":
        h['nota']="PROPOSTA: filhote do Ambarion (dragão guardião da Rota do Âmbar, que fica na entrada da doca)."
    out.append(h)
d={"versao":2,"area":"porto_velho","moradores_do_mapa":True,
   "nota":"Integracao 20/10 (PROPOSTA): elenco da Bolorina (scripts/dialogos/npcs_registro.gd) com as 20 lojas e servicos do Claude. "
          "Quem tem 'morador' e o NPC do proprio mapa (rosto, corpo e dialogo da Bolorina); E conversa pelo Dialogue Manager e, ao fim da conversa, abre o balcao da loja. "
          "Quem nao tem 'morador' e morador novo do Claude, desenhado pelo adaptador na 'pos' (x,z) livre mais proxima. Tabela: docs/ELENCO_UNIFICADO.md. "
          "Roster provisorio original: data/npcs/porto_velho_provisorio.json.",
   "npcs":out}
open('data/npcs/porto_velho.json','w',encoding='utf-8').write(json.dumps(d,ensure_ascii=False,indent=1))
print(len(out),'npcs')
