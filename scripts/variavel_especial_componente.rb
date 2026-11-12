# Rodar o script APENAS com o componente selecionado

mod = Sketchup.active_model
sel = mod.selection.first

if sel.nil?
  puts "ERRO: Selecione o componente do Kit antes de rodar."
else
  mod.start_operation('Configurar Especial Kit Linea', true)

  # Se o item baixado do 3D Warehouse estiver como Grupo, converte para Componente
  if sel.is_a?(Sketchup::Group)
    nome = sel.name.empty? ? 'Kit Linea Painel' : sel.name
    sel = sel.to_component
    sel.definition.name = nome
    mod.selection.clear
    mod.selection.add(sel)
  end

  if sel.is_a?(Sketchup::ComponentInstance)
    dict = 'dynamic_attributes'
    defn = sel.definition

    # Configura o atributo 'especial' como lista suspensa (20kg / 30kg)
    [sel, defn].each do |target|
      target.set_attribute(dict, 'especial', '20kg')
      target.set_attribute(dict, '_especial_label', 'especial')
      target.set_attribute(dict, '_especial_formlabel', 'Capacidade Kit Linea')
      target.set_attribute(dict, '_especial_access', 'LIST')
      target.set_attribute(dict, '_especial_options', '&Linea 20kg=20kg&Linea 30kg=30kg&')
    end

    # Atualiza a interface de Componentes Dinâmicos
    if defined?($dc_observers)
      $dc_observers.get_latest_class.redraw_with_undo(sel)
    end

    puts "[SUCESSO] Atributo 'especial' criado em: #{defn.name}"
    puts "Abra a janela 'Opcoes de Componentes' para alternar entre 20kg e 30kg."
  else
    puts "ERRO: O item selecionado nao e um Grupo ou Componente."
  end

  mod.commit_operation
end