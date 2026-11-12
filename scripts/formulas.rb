model = Sketchup.active_model
selection = model.selection

if selection.empty?
  UI.messagebox("⚠️ Selecione um componente na tela antes de rodar o script.")
else
  path = UI.savepanel("Salvar Relatório de Fórmulas Dinâmicas", "", "formulas_componente.txt")
  
  if path
    File.open(path, "w:UTF-8") do |file|
      file.puts "=== RELATÓRIO DE ATRIBUTOS E FÓRMULAS DINÂMICAS ==="
      file.puts "Data: #{Time.now}"
      file.puts "=" * 60
      
      selection.each do |entity|
        next unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
        
        file.puts "\n\n[COMPONENTE PRINCIPAL]: #{entity.name}"
        file.puts "-" * 40
        dict = entity.attribute_dictionary('dynamic_attributes')
        if dict
          dict.keys.sort.each do |key|
            file.puts "  #{key} = #{dict[key]}"
          end
        else
          file.puts "  (Sem atributos dinâmicos)"
        end
        
        file.puts "\n--- SUBCOMPONENTES INTERNOS ---"
        entity.definition.entities.each do |sub|
          next unless sub.is_a?(Sketchup::ComponentInstance) || sub.is_a?(Sketchup::Group)
          
          file.puts "\n  > Subcomponente: #{sub.name}"
          sub_dict = sub.attribute_dictionary('dynamic_attributes')
          if sub_dict
            sub_dict.keys.sort.each do |sub_key|
              file.puts "    #{sub_key} = #{sub_dict[sub_key]}"
            end
          else
            file.puts "    (Sem atributos dinâmicos)"
          end
        end
      end
    end
    
    UI.messagebox("✅ Arquivo TXT criado com sucesso!\nSalvo em: #{path}")
  end
end