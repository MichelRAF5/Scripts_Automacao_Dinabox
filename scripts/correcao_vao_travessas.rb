model = Sketchup.active_model
selection = model.selection

if selection.empty?
  UI.messagebox("⚠️ Selecione o componente principal do gaveteiro.")
else
  model.start_operation("Expandir Gaveteiro para 100% do Vao", true)
  
  selection.each do |entity|
    next unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
    
    # Pega o xlargura atual (vão total do balcão, ex: 86.6 cm)
    xlargura = entity.get_attribute('dynamic_attributes', 'xlargura')
    xlargura_val = xlargura ? xlargura.to_f : 86.6
    
    # Converte os centímetros totais do vão para polegadas (padrão do LenX no SketchUp)
    lenx_in = xlargura_val / 2.54
    
    # Aplica a largura total diretamente no LenX do bloco principal, zerando os recuos de subtração (re e rd)
    entity.set_attribute('dynamic_attributes', 'LenX', lenx_in)
    entity.set_attribute('dynamic_attributes', '_lenx_formula', xlargura_val.to_s)
    
    entity.set_attribute('dynamic_attributes', 're', '0')
    entity.set_attribute('dynamic_attributes', '_re_formula', '0')
    
    entity.set_attribute('dynamic_attributes', 'rd', '0')
    entity.set_attribute('dynamic_attributes', '_rd_formula', '0')
    
    # Redesenha o componente para atualizar a geometria das gavetas e manter as travessas intactas
    if defined?($dc_observers) && $dc_observers.respond_to?(:get_latest_class)
      $dc_observers.get_latest_class.redraw(entity)
    end
  end
  
  model.commit_operation
  UI.messagebox("✅ Sucesso! O bloco agora ocupa 100% do vão livre e as travessas foram preservadas.")
endmodel = Sketchup.active_model
selection = model.selection

if selection.empty?
  UI.messagebox("⚠️ Selecione o componente principal do gaveteiro.")
else
  model.start_operation("Expandir Gaveteiro para 100% do Vao", true)
  
  selection.each do |entity|
    next unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
    
    # Pega o xlargura atual (vão total do balcão, ex: 86.6 cm)
    xlargura = entity.get_attribute('dynamic_attributes', 'xlargura')
    xlargura_val = xlargura ? xlargura.to_f : 86.6
    
    # Converte os centímetros totais do vão para polegadas (padrão do LenX no SketchUp)
    lenx_in = xlargura_val / 2.54
    
    # Aplica a largura total diretamente no LenX do bloco principal, zerando os recuos de subtração (re e rd)
    entity.set_attribute('dynamic_attributes', 'LenX', lenx_in)
    entity.set_attribute('dynamic_attributes', '_lenx_formula', xlargura_val.to_s)
    
    entity.set_attribute('dynamic_attributes', 're', '0')
    entity.set_attribute('dynamic_attributes', '_re_formula', '0')
    
    entity.set_attribute('dynamic_attributes', 'rd', '0')
    entity.set_attribute('dynamic_attributes', '_rd_formula', '0')
    
    # Redesenha o componente para atualizar a geometria das gavetas e manter as travessas intactas
    if defined?($dc_observers) && $dc_observers.respond_to?(:get_latest_class)
      $dc_observers.get_latest_class.redraw(entity)
    end
  end
  
  model.commit_operation
  UI.messagebox("✅ Sucesso! O bloco agora ocupa 100% do vão livre e as travessas foram preservadas.")
end