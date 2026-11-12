# diagnostico_dinabox.rb
# Diagnostico SOMENTE LEITURA de um componente Dinabox (nao altera nada no modelo).
# Serve de base para comparar um componente RESPONSIVO com um NAO RESPONSIVO.
#
# O que registra (tudo em mm, salvo onde indicado):
#   [PARAMETROS]    medidas e parametros-chave (lenx, xlargura, re/rd, re2/rd2, px...), cada um com
#                   a formula inteira e o tipo: FIXO (numero), LOCAL (formula interna) ou LIGADA (usa "alvo!atributo")
#   [TRAVESSAS]     por lado (ESQ/DIR): posicao, espessura, orientacao (eixos locais e normal),
#                   espacamento entre camadas e folga ate a face interna da lateral do balcao
#   [PECAS]         todas as pecas: posicao, medidas, orientacao, formulas inteiras de medida/posicao,
#                   referencias a outros componentes (resolvidas ou nao) e divergencia instancia x definicao
#   [ESPACAMENTO]   por container e por eixo X/Y/Z: intervalo de cada peca e folga para a anterior
#   [BRUTO]         dump completo (sem cortes) dos atributos da raiz, gaveteiros e travessas

require "fileutils"

module DinaboxDiag
  DICT = "dynamic_attributes".freeze
  MM   = 25.4   # SketchUp mede em polegadas

  # ---------- configuracao ----------
  MAX_PROF = 6                                  # profundidade maxima da varredura
  IGNORAR  = /furo|parafuso|pino|cavilha|contorno|corredi/i   # pecas ignoradas (nome ou definicao)
  BRUTO    = :raiz_e_travessas                  # :nenhum, :raiz, :raiz_e_travessas ou :tudo

  # Travessas: a peca vale se QUALQUER criterio casar
  PADROES = {
    :nome => /travessa\s+(esquerda|direita)/i,  # atributo name/db01
    :dc   => /\A(re|rd)2(_|\z)/,                # atributo _name do DC
    :def  => /recuo_(esquerdo|direito)/i        # nome da definicao
  }

  # Atributos que sempre sao listados em [PARAMETROS]
  PARAMS = %w[lenx leny lenz x y z xlargura xaltura xposicaox xposicaoz re rd re2 rd2
              px py pz alx aly apx apy caep caes caeb caet invmonrec ltr invtravlat
              tamtravlat bmod removts tlar trav_rec zrecint rp]
  EM_POLEGADAS = %w[lenx leny lenz x y z]       # valores guardados em polegadas pelo DC
  CHAVES_DIM   = %w[lenx leny lenz x y z px py pz rotx roty rotz hidden]

  # ---------- utilitarios ----------

  def self.ler(o, k)                    # instancia primeiro, depois definicao
    v = o.get_attribute(DICT, k)
    v = o.definition.get_attribute(DICT, k) if v.nil?
    v
  end

  def self.num(v)
    v.to_s.tr(",", ".").to_f
  end

  def self.f1(n)
    n.nil? ? "-" : format("%.1f", n)
  end

  def self.trio(a)
    a.map { |v| f1(v) }.join(" x ")
  end

  def self.container?(e)
    e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
  end

  def self.filhos(ent)
    es = ent.is_a?(Sketchup::Group) ? ent.entities : ent.definition.entities
    es.select { |e| container?(e) }
  end

  def self.rotulo(e)
    n = ler(e, "name").to_s
    n = ler(e, "db01").to_s if n.empty?
    n = e.name.to_s if n.empty?
    n = e.definition.name.to_s.sub(/#\d+\z/, "") if n.empty?
    n = "(sem nome)" if n.empty?
    n.gsub(/[\r\n]+/, " ")
  end

  def self.ignorar?(e)
    !((rotulo(e) + " " + e.definition.name.to_s) =~ IGNORAR).nil?
  end

  def self.gaveteiro?(e)
    container?(e) && %w[re2 rd2 xlargura xposicaox].all? { |k| !ler(e, k).nil? }
  end

  def self.travessa?(t)
    return false unless container?(t)
    nome = (ler(t, "name") || ler(t, "db01")).to_s
    dc   = ler(t, "_name").to_s
    !!((nome =~ PADROES[:nome]) || (dc =~ PADROES[:dc]) || (t.definition.name.to_s =~ PADROES[:def]))
  end

  def self.alinhar(v)
    v = v.normalize
    c = [v.x, v.y, v.z]
    i = 0
    i = 1 if c[1].abs > c[i].abs
    i = 2 if c[2].abs > c[i].abs
    if c[i].abs > 0.999
      (c[i] > 0 ? "+" : "-") + %w[X Y Z][i]
    else
      format("obliquo(%.2f,%.2f,%.2f)", c[0], c[1], c[2])
    end
  end

  def self.eixos_txt(tr)
    "X>#{alinhar(tr.xaxis)} Y>#{alinhar(tr.yaxis)} Z>#{alinhar(tr.zaxis)}"
  end

  def self.normal_txt(dims)
    i = 0
    i = 1 if dims[1] < dims[i]
    i = 2 if dims[2] < dims[i]
    "#{%w[X Y Z][i]} (espessura #{f1(dims[i])} mm)"
  end

  # Formula efetiva (instancia, senao definicao) de uma chave: "_<chave>_formula"
  def self.formula(ent, k)
    f = ent.get_attribute(DICT, "_#{k}_formula")
    f = ent.definition.get_attribute(DICT, "_#{k}_formula") if f.nil?
    f
  end

  def self.tipo(f)
    return "-" if f.nil?
    s = f.to_s.strip
    return "FIXO" if s =~ /\A-?\d+(\.\d+)?\z/
    s.include?("!") ? "LIGADA" : "LOCAL"
  end

  def self.nomes_irmaos(ent)
    pai = ent.parent
    es = pai.respond_to?(:entities) ? pai.entities : []
    es.select { |e| container?(e) }.map { |e| ler(e, "_name").to_s.downcase }.reject { |n| n.empty? }
  rescue
    []
  end

  # ---------- coleta ----------

  def self.coletar(ent, caminho, prof)
    bb = ent.bounds
    t  = ent.transformation
    no = {
      :ent => ent, :caminho => caminho, :prof => prof,
      :min => [bb.min.x * MM, bb.min.y * MM, bb.min.z * MM],
      :max => [bb.max.x * MM, bb.max.y * MM, bb.max.z * MM],
      :dim => [bb.width * MM, bb.height * MM, bb.depth * MM],
      :origem => [t.origin.x * MM, t.origin.y * MM, t.origin.z * MM],
      :tr => t,
      :filhos => []
    }
    return no if prof >= MAX_PROF
    ocorr = Hash.new(0)
    filhos(ent).each do |f|
      next if ignorar?(f)
      rot = rotulo(f)
      ocorr[rot] += 1
      no[:filhos] << coletar(f, "#{caminho}/#{rot}[#{ocorr[rot]}]", prof + 1)
    end
    no
  end

  def self.todos(no, acc = [])
    acc << no
    no[:filhos].each { |f| todos(f, acc) }
    acc
  end

  # ---------- secoes ----------

  def self.secao_parametros(no, l)
    e = no[:ent]
    c = no[:caminho]
    l << "#{c} :: nome = #{rotulo(e)}"
    l << "#{c} :: medida.bounds_mm = #{trio(no[:dim])}"
    l << "#{c} :: medida.origem_mm = #{no[:origem].map { |v| f1(v) }.join(', ')}"
    l << "#{c} :: medida.escala = #{format('%.4f', no[:tr].xscale)}, #{format('%.4f', no[:tr].yscale)}, #{format('%.4f', no[:tr].zscale)}"
    PARAMS.each do |p|
      v = ler(e, p)
      f = formula(e, p)
      next if v.nil? && f.nil?
      val = EM_POLEGADAS.include?(p) ? "#{f1(num(v) * MM)} mm" : v.to_s
      l << "#{c} :: param.#{p} = #{val} | formula=#{f.inspect} | #{tipo(f)}"
    end
  end

  def self.secao_pecas(no, l)
    e = no[:ent]
    c = no[:caminho]
    ocultos = e.hidden? || !e.layer.visible?
    l << "#{c} :: definicao = #{e.definition.name.to_s.sub(/#\d+\z/, '')}"
    l << "#{c} :: _name = #{ler(e, '_name')}" unless ler(e, "_name").nil?
    l << "#{c} :: oculto = #{ocultos}"
    l << "#{c} :: pos.min_mm = #{no[:min].map { |v| f1(v) }.join(', ')}"
    l << "#{c} :: pos.max_mm = #{no[:max].map { |v| f1(v) }.join(', ')}"
    l << "#{c} :: dim_mm_eixos_do_pai = #{trio(no[:dim])}"
    len = %w[lenx leny lenz].map { |k| ler(e, k) }
    l << "#{c} :: dim_dc_mm = #{len.map { |v| v.nil? ? '-' : f1(num(v) * MM) }.join(' x ')}" unless len.compact.empty?
    l << "#{c} :: eixos_locais = #{eixos_txt(no[:tr])}"
    l << "#{c} :: normal = #{normal_txt(no[:dim])}"

    # Captura TODAS as formulas existentes na instancia e definicao, sem limitar apenas a CHAVES_DIM
    forms = {}
    [e.definition, e].each do |o|
      d = o.attribute_dictionary(DICT)
      next if d.nil?
      d.keys.sort.each do |k|
        if k.to_s =~ /\A_(.+)_formula\z/
          attr_base = $1
          forms[attr_base] = d[k] unless d[k].nil?
        end
      end
    end

    modo = if forms.empty? then "SEM-DC"
           elsif forms.values.any? { |f| tipo(f) == "LIGADA" } then "LIGADA"
           elsif forms.values.any? { |f| tipo(f) == "LOCAL" } then "LOCAL"
           else "FIXA" end
    l << "#{c} :: responsividade = #{modo}"
    forms.each { |k, f| l << "#{c} :: formula.#{k} = #{f} [#{tipo(f)}]" }

    # referencias "alvo!atributo" em todas as formulas (instancia e definicao)
    refs = []
    [e, e.definition].each do |o|
      d = o.attribute_dictionary(DICT)
      next if d.nil?
      d.each_pair do |k, v|
        next unless k.to_s =~ /\A_.+_formula\z/ && v.is_a?(String)
        v.scan(/([A-Za-z_]\w*)!([A-Za-z_]\w*)/) { |a, b| refs << [a, b] }
      end
    end
    refs.uniq!
    unless refs.empty?
      irm = nomes_irmaos(e)
      txt = refs.map do |a, b|
        st = a.downcase == "parent" ? "pai" : (irm.include?(a.downcase) ? "irmao" : "?")
        "#{a}!#{b}(#{st})"
      end
      l << "#{c} :: refs = #{txt.sort.join(', ')}"
    end

    # formulas que diferem entre instancia e definicao (sem limite de quantidade)
    di = e.attribute_dictionary(DICT)
    dd = e.definition.attribute_dictionary(DICT)
    if di && dd
      di.keys.sort.each do |k|
        next unless k.to_s =~ /\A_.+_formula\z/
        v = di[k]
        w = dd[k]
        next if w.nil? || w == v
        l << "#{c} :: diverge.#{k} = inst=#{v.inspect} def=#{w.inspect}"
      end
    end
  end

  def self.secao_espacamento(no, l)
    fs = no[:filhos]
    if fs.size >= 2
      %w[X Y Z].each_with_index do |eixo, a|
        corte = nil
        fs.sort_by { |f| [f[:min][a], f[:caminho]] }.each do |f|
          gap = corte.nil? ? nil : f[:min][a] - corte
          corte = corte.nil? ? f[:max][a] : [corte, f[:max][a]].max
          seg = f[:caminho].split("/").last
          g = gap.nil? ? "-" : (gap < -0.05 ? "#{f1(gap)} (SOBREPOSTO)" : f1(gap))
          l << "#{no[:caminho]} :: esp.#{eixo}.#{seg} = #{f1(f[:min][a])} .. #{f1(f[:max][a])} | gap_anterior=#{g}"
        end
      end
    end
    fs.each { |f| secao_espacamento(f, l) }
  end

  # Travessas de um gaveteiro, medidas no sistema de coordenadas do balcao (pai do gaveteiro)
  def self.secao_travessas(no, l)
    g = no[:ent]
    c = no[:caminho]
    ts = filhos(g).select { |t| travessa?(t) && !t.hidden? }
    return if ts.empty?

    xl = ler(g, "xlargura")
    xp = ler(g, "xposicaox")
    tem_faces = !xl.nil? && !xp.nil?
    fe = tem_faces ? num(xp) * 10.0 : nil
    fd = tem_faces ? fe + num(xl) * 10.0 : nil
    if tem_faces
      l << "#{c} :: faces.interna_esq_mm = #{f1(fe)}"
      l << "#{c} :: faces.interna_dir_mm = #{f1(fd)}"
    end
    re = ler(g, "re")
    rd = ler(g, "rd")
    l << "#{c} :: recuo.re_mm = #{f1(num(re) * 10.0)}" unless re.nil?
    l << "#{c} :: recuo.rd_mm = #{f1(num(rd) * 10.0)}" unless rd.nil?

    itens = ts.map do |t|
      pts = (0..7).map { |i| g.transformation * t.bounds.corner(i) }
      xs = pts.map { |p| p.x * MM }
      ys = pts.map { |p| p.y * MM }
      zs = pts.map { |p| p.z * MM }
      dims = [xs.max - xs.min, ys.max - ys.min, zs.max - zs.min]
      { :t => t, :mn => xs.min, :mx => xs.max, :dims => dims, :tr => g.transformation * t.transformation }
    end
    meio = tem_faces ? (fe + fd) / 2.0 : (itens.map { |i| i[:mn] }.min + itens.map { |i| i[:mx] }.max) / 2.0

    [["ESQ", itens.select { |i| (i[:mn] + i[:mx]) / 2.0 < meio }],
     ["DIR", itens.select { |i| (i[:mn] + i[:mx]) / 2.0 >= meio }]].each do |lado, lista|
      next if lista.empty?
      lista = lista.sort_by { |i| i[:mn] }
      ant = nil
      lista.each_with_index do |i, n|
        k = "#{c}/travessa.#{lado}[#{n + 1}]"
        l << "#{k} :: peca = #{rotulo(i[:t])}"
        l << "#{k} :: x_mm_balcao = #{f1(i[:mn])} .. #{f1(i[:mx])}"
        l << "#{k} :: extensao_mm_xyz = #{trio(i[:dims])}"
        l << "#{k} :: eixos_locais = #{eixos_txt(i[:tr])}"
        l << "#{k} :: normal = #{normal_txt(i[:dims])}"
        l << "#{k} :: gap_peca_anterior_mm = #{f1(i[:mn] - ant[:mx])}" unless ant.nil?
        ant = i
      end
      ext_min = lista.map { |i| i[:mn] }.min
      ext_max = lista.map { |i| i[:mx] }.max
      l << "#{c}/travessa.#{lado} :: camadas = #{lista.size}"
      l << "#{c}/travessa.#{lado} :: profundidade_total_mm = #{f1(ext_max - ext_min)}"
      if tem_faces
        gap = lado == "ESQ" ? ext_min - fe : fd - ext_max
        l << "#{c}/travessa.#{lado} :: gap_face_interna_mm = #{f1(gap)}"
      end
    end
  end

  def self.bruto(ent, cam, l)
    [["instancia", ent], ["definicao", ent.definition]].each do |origem, o|
      dicts = o.attribute_dictionaries
      next if dicts.nil?
      lista = []
      dicts.each { |d| lista << d }
      lista.sort_by { |d| d.name.to_s }.each do |d|
        d.keys.sort.each do |k|
          # Registra o valor/formula inteiro sem truncar em 300 caracteres
          l << "#{cam} :: raw.#{origem}.#{d.name}.#{k} = #{d[k].inspect}"
        end
      end
    end
  end

  # ---------- execucao ----------

  def self.pasta_saida
    base = File.join(Dir.home, "Desktop")
    base = Dir.home unless File.directory?(base)
    pasta = File.join(base, "automacaoDinabox", Time.now.strftime("%Y-%m-%d"))
    FileUtils.mkdir_p(pasta)
    pasta
  end

  def self.rodar
    model = Sketchup.active_model
    sel = model.selection.to_a.select { |e| container?(e) }
    if sel.empty?
      UI.messagebox("Selecione o gaveteiro (ou o balcao que o contem) antes de rodar.")
      return
    end
    r = UI.inputbox(["Rotulo do arquivo (ex.: responsivo, nao_responsivo)"], ["diagnostico"], "Diagnostico Dinabox")
    return if r.nil? || r == false
    rotulo = r[0].to_s.strip.gsub(/[^\w\-]+/, "_")
    rotulo = "diagnostico" if rotulo.empty?

    raizes = []
    sel.each_with_index do |e, i|
      raizes << coletar(e, sel.size > 1 ? "RAIZ#{i + 1}" : "RAIZ", 0)
    end
    nos = []
    raizes.each { |rz| todos(rz, nos) }
    gavs = nos.select { |n| gaveteiro?(n[:ent]) }

    l = []
    l << "# Diagnostico Dinabox - #{rotulo}"
    l << "# Gerado em #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} | SketchUp #{Sketchup.version}"
    l << "# Arquivo do modelo: #{model.path.to_s.empty? ? '(nao salvo)' : model.path}"
    l << "# Selecionados: #{sel.size} | pecas varridas: #{nos.size} | gaveteiros: #{gavs.size} | profundidade max: #{MAX_PROF}"
    l << "# Linhas de dados: 'chave = valor'. Linhas com # sao ignoradas na comparacao."
    l << ""
    l << "# ===== [PARAMETROS] ====="
    (raizes.map { |rz| rz } + gavs.reject { |n| raizes.include?(n) }).each { |n| secao_parametros(n, l) }
    l << ""
    l << "# ===== [TRAVESSAS] ====="
    gavs.each { |n| secao_travessas(n, l) }
    l << ""
    l << "# ===== [PECAS] ====="
    nos.each { |n| secao_pecas(n, l) }
    l << ""
    l << "# ===== [ESPACAMENTO] ====="
    raizes.each { |rz| secao_espacamento(rz, l) }
    unless BRUTO == :nenhum
      l << ""
      l << "# ===== [BRUTO] ====="
      nos.each do |n|
        e = n[:ent]
        quer = (BRUTO == :tudo) || (n[:prof] == 0) ||
               (BRUTO == :raiz_e_travessas && (gaveteiro?(e) || travessa?(e)))
        bruto(e, n[:caminho], l) if quer
      end
    end

    arquivo = File.join(pasta_saida, "diag_#{rotulo}.txt")
    File.open(arquivo, "w:UTF-8") { |f| f.puts(l) }
    puts "Diagnostico gravado em: #{arquivo} (#{l.size} linhas)"
    UI.messagebox("Diagnostico gravado em:\n#{arquivo}\n\n#{l.size} linhas | #{nos.size} pecas | #{gavs.size} gaveteiro(s)")
  end

  # ---------- comparacao de dois diagnosticos ----------

  def self.ler_chaves(arq, incluir_bruto)
    h = {}
    File.readlines(arq, :encoding => "UTF-8").each do |ln|
      ln = ln.chomp
      next if ln.empty? || ln.start_with?("#")
      i = ln.index(" = ")
      next if i.nil?
      chave = ln[0...i]
      next if chave =~ /(::\s_name\z)|(\._name\z)|(_lastmodified\z)/   # ruido (sufixos aleatorios)
      next if !incluir_bruto && chave.include?(":: raw.")
      h[chave] = ln[(i + 3)..-1]
    end
    h
  end

  def self.comparar(arq_a, arq_b, incluir_bruto = false)
    a = ler_chaves(arq_a, incluir_bruto)
    b = ler_chaves(arq_b, incluir_bruto)
    so_a = (a.keys - b.keys).sort
    so_b = (b.keys - a.keys).sort
    dif  = (a.keys & b.keys).select { |k| a[k] != b[k] }.sort
    out = []
    out << "# Comparacao: A=#{File.basename(arq_a)}  B=#{File.basename(arq_b)}  (bruto: #{incluir_bruto ? 'incluido' : 'omitido'})"
    out << "# So no A: #{so_a.size} | So no B: #{so_b.size} | Diferentes: #{dif.size} | Iguais: #{(a.keys & b.keys).size - dif.size}"
    out << ""
    out << "# ===== DIFERENTES (A  ->  B) ====="
    dif.each { |k| out << "#{k}\n    A: #{a[k]}\n    B: #{b[k]}" }
    out << ""
    out << "# ===== SO NO A ====="
    so_a.each { |k| out << "#{k} = #{a[k]}" }
    out << ""
    out << "# ===== SO NO B ====="
    so_b.each { |k| out << "#{k} = #{b[k]}" }
    saida = File.join(File.dirname(arq_a), "comparacao_#{File.basename(arq_a, '.txt')}_vs_#{File.basename(arq_b, '.txt')}.txt")
    File.open(saida, "w:UTF-8") { |f| f.puts(out) }
    puts "Comparacao gravada em: #{saida}"
    saida
  end
end

# Ao carregar: se ha algo selecionado, ja roda; senao so deixa as funcoes disponiveis
if Sketchup.active_model.selection.empty?
  puts "diagnostico_dinabox.rb carregado. Selecione o componente e rode DinaboxDiag.rodar, " \
       "ou compare com DinaboxDiag.comparar(arquivo_a, arquivo_b)."
else
  DinaboxDiag.rodar
end