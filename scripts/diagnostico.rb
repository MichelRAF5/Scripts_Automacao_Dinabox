# ==============================================================================
# Script de Diagnóstico e Exportação para TXT - DinaBox
# Cole este código no Console Ruby do SketchUp com o módulo selecionado.
# ==============================================================================

model = Sketchup.active_model
selection = model.selection

if selection.empty?
  UI.messagebox("Erro: Selecione o componente principal do módulo DinaBox antes de executar o script.")
else
  # Define o caminho na Área de Trabalho do usuário (Windows / Mac)
  desktop_path = File.join(Dir.home, "Desktop")
  desktop_path = File.join(Dir.home, "Área de Trabalho") unless File.directory?(desktop_path)
  desktop_path = Dir.home unless File.directory?(desktop_path)
  
  file_path = File.join(desktop_path, "dinabox_diagnostico.txt")

  File.open(file_path, "w:UTF-8") do |file|
    file.puts "========================================================"
    file.puts " ANÁLISE DE ATRIBUTOS DINÂMICOS - DINABOX"
    file.puts " Data/Hora: #{Time.now.strftime('%d/%m/%Y %H:%M:%S')}"
    file.puts "========================================================"
    
    # Função recursiva para varrer todos os subcomponentes e escrever no arquivo
    analisar_entidade = lambda do |entity, depth|
      indent = "  " * depth
      if entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
        def_name = entity.definition.name
        inst_name = entity.name
        
        file.puts "#{indent}----------------------------------------------------"
        file.puts "#{indent}[Instância]: '#{inst_name}' | [Definição]: '#{def_name}'"
        
        dict = entity.attribute_dictionary("dynamic_components")
        if dict
          # Lista todas as chaves e fórmulas dinâmicas do componente
          dict.each_pair do |k, v|
            file.puts "#{indent}  -> #{k} = #{v}"
          end
        else
          file.puts "#{indent}  (Sem dicionário de Atributos Dinâmicos nesta camada)"
        end

        entity.definition.entities.each { |child| analisar_entidade.call(child, depth + 1) }
      end
    end

    selection.each { |sel| analisar_entidade.call(sel, 0) }
    
    file.puts "========================================================"
    file.puts " FIM DO RELATÓRIO"
    file.puts "========================================================"
  end

  UI.messagebox("Sucesso! Arquivo salvo em:\n#{file_path}")
  puts "Arquivo criado com sucesso em: #{file_path}"
end