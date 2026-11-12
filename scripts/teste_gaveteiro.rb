model = Sketchup.active_model
sel = model.selection

if sel.empty? || !sel.first.is_a?(Sketchup::ComponentInstance)
  UI.messagebox("Por favor, selecione o componente do gaveteiro antes de executar o script.")
else
  model.start_operation("Configurar Gaveteiro Oculta Estilo Base", true)
  
  gaveteiro = sel.first
  dict = "dynamic_attributes"
  dc_class = defined?($dc_observers) ? $dc_observers.get_latest_class : nil

  # 1. Atributos gerais do gaveteiro ajustados conforme o modelo base
  attrs_gerais = {
    "gfrf" => 1.0,
    "gfrl" => 0.9,
    "grin" => 2.0,
    "gfol" => 2.5,
    "prin" => 0.5,
    "prin2" => 0.5,
    "prsu" => 0.5,
    "prsu2" => 0.5,
    "prdi" => 0.7,
    "prdi2" => 0.7
  }
  
  attrs_gerais.each do |k, v|
    gaveteiro.set_attribute(dict, k, v)
    gaveteiro.definition.set_attribute(dict, k, v)
  end

  # 2. Mapeamento exato de posições e fórmulas para as travessas e cópias
  mapa = {
    "re2"                 => [-1.5, "=-1.5"],
    "re2_c571194"         => [-3.0, "=-3.0"],
    "re2_c571194_c841552" => [-4.5, "=-4.5"],
    "rd2"                 => [73.4, "=parent!LenX"],
    "rd2_c267027"         => [75.0, "=parent!LenX+1.6"],
    "rd2_c267027_c102059" => [76.6, "=parent!LenX+3.2"],
    "re2_c304053"         => [0.0,  "=0"],
    "re2_2659"            => [-1.6, "=-1.6"],
    "re2_c652335"         => [-3.2, "=-3.2"],
    "rd2_8916"            => [73.4, "=parent!LenX"],
    "rd2_c802913"         => [75.0, "=parent!LenX+1.6"],
    "rd2_c802913_c542374" => [76.6, "=parent!LenX+3.2"]
  }

  # 3. Varre e atualiza recursivamente as subpartes e os subcomponentes internos
  def process_entities(entity_container, dict, mapa, dc_class)
    entity_container.definition.entities.grep(Sketchup::ComponentInstance).each do |sub|
      nome = sub.name

      if mapa.key?(nome)
        val, form = mapa[nome]
        sub.set_attribute(dict, "x", val)
        sub.set_attribute(dict, "_x_formula", form)
        sub.definition.set_attribute(dict, "x", val)
        sub.definition.set_attribute(dict, "_x_formula", form)
      end

      if nome.start_with?("dinabox_porta__")
        sub.set_attribute(dict, "x", -1.5)
        sub.set_attribute(dict, "_x_formula", "=-1.5")
        sub.set_attribute(dict, "lenx", 76.4)
        sub.set_attribute(dict, "_lenx_formula", "=parent!LenX+3.0")
        sub.definition.set_attribute(dict, "x", -1.5)
        sub.definition.set_attribute(dict, "_x_formula", "=-1.5")
        sub.definition.set_attribute(dict, "lenx", 76.4)
        sub.definition.set_attribute(dict, "_lenx_formula", "=parent!LenX+3.0")
      end

      # Recursão para garantir que sub-níveis também recebam o redraw
      process_entities(sub, dict, mapa, dc_class) if sub.definition.entities.grep(Sketchup::ComponentInstance).any?
      
      dc_class.redraw(sub) if dc_class
    end
  end

  process_entities(gaveteiro, dict, mapa, dc_class)

  # 4. Força o redesenho e a atualização global da tela no SketchUp
  dc_class.redraw(gaveteiro) if dc_class
  model.active_view.invalidate
  
  model.commit_operation
  UI.messagebox("Gaveteiro ajustado, travessas alinhadas e redesenhadas via Ruby com sucesso!")
end