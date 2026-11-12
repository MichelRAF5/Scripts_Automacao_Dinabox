# Rodar o script APENAS com o módulo selecionado

mod = Sketchup.active_model
sel = mod.selection.first

if sel.nil? || !sel.is_a?(Sketchup::ComponentInstance)
  puts "ERRO: Selecione o Balcao/Modulo inteiro na tela antes de rodar."
else
  mod.start_operation('Injetar Especial no Pistao Embutido', true)
  
  contador = 0
  
  # Função recursiva para varrer todas as peças filhas dentro do armário
  def varrer_e_injetar(component_instance)
    count = 0
    defn = component_instance.definition
    
    # Procura por palavras-chave no nome da definição ou da instância que indiquem o pistão/gas
    nome_baixo = (defn.name + " " + component_instance.name).downcase
    if nome_baixo.include?("pistao") || nome_baixo.include?("gas") || nome_baixo.include?("amortecedor") || nome_baixo.include?("basculante")
      
      dict = 'dynamic_attributes'
      [component_instance, defn].each do |target|
        target.set_attribute(dict, 'especial', '80N')
        target.set_attribute(dict, '_especial_label', 'especial')
        target.set_attribute(dict, '_especial_formlabel', 'Força do Pistão')
        target.set_attribute(dict, '_especial_access', 'LIST')
        target.set_attribute(dict, '_especial_options', '&Pistao 80N=80N&Pistao 100N=100N&')
      end
      
      if defined?($dc_observers)
        $dc_observers.get_latest_class.redraw_with_undo(component_instance)
      end
      
      puts "[ENCONTRADO E CONFIGURADO] Subcomponente: #{defn.name}"
      count += 1
    end
    
    # Entra nos subcomponentes (filhos)
    defn.entities.grep(Sketchup::ComponentInstance).each do |filho|
      count += varrer_e_injetar(filho)
    end
    
    count
  end
  
  contador = varrer_e_injetar(sel)
  
  mod.commit_operation
  
  if contador > 0
    puts "\n[SUCESSO] Total de elementos de pistão configurados: #{contador}"
    puts "Agora abra as 'Opções de Componentes' (ou clique no balcão) para ver a opção de força do pistão!"
  else
    puts "\n[AVISO] Nenhum subcomponente com nome de pistao foi encontrado dentro desse modulo."
    puts "Verifique se o nome do pistão dentro do modelo tem outro termo (ex: 'amortecedor')."
  end
end