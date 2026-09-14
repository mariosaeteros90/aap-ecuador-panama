*==============================================================
* RUTINAS REUTILIZABLES
* Todas asumen un archivo .dta con: anio, hs6, valor (USD)
*==============================================================

*--------------------------------------------------------------
* r_conc : concentracion HHI, CR5, CR10 por grupo
*--------------------------------------------------------------
cap program drop r_conc
program define r_conc
    syntax , IN(string) GROUP(string) OUT(string)
    use "`in'", clear
    collapse (sum) valor, by(`group' hs6)
    drop if valor <= 0
    bysort `group': egen double _tot = total(valor)
    gen double _sh  = valor/_tot
    gen double _sh2 = _sh^2
    gsort `group' -valor
    by `group': gen int _r = _n
    by `group': egen double _c5  = total(valor*(_r<=5))
    by `group': egen double _c10 = total(valor*(_r<=10))
    collapse (sum) hhi=_sh2 (max) _c5 _c10 (mean) _tot (count) n_hs6=_sh, by(`group')
    gen double cr5  = 100*_c5/_tot
    gen double cr10 = 100*_c10/_tot
    replace hhi = 10000*hhi
    gen double valor_musd = _tot/1e6
    drop _c5 _c10 _tot
    order `group' n_hs6 valor_musd hhi cr5 cr10
    save "`out'", replace
end

*--------------------------------------------------------------
* r_margenes : descomposicion intensivo / extensivo / salida
* La contribucion de cada categoria es el delta de valor, de modo
* que intensivo + nuevos + salen = cambio total, exactamente.
*--------------------------------------------------------------
cap program drop r_margenes
program define r_margenes
    syntax , IN(string) T0(int) T1(int) UMBRAL(real) OUT(string)
    use "`in'", clear
    keep if inlist(anio,`t0',`t1')
    collapse (sum) valor, by(hs6 anio)
    reshape wide valor, i(hs6) j(anio)
    cap confirm variable valor`t0'
    if _rc gen double valor`t0' = 0
    cap confirm variable valor`t1'
    if _rc gen double valor`t1' = 0
    replace valor`t0' = 0 if missing(valor`t0')
    replace valor`t1' = 0 if missing(valor`t1')
    gen byte p0 = valor`t0' > `umbral'
    gen byte p1 = valor`t1' > `umbral'
    gen double delta = valor`t1' - valor`t0'
    gen byte cat = .
    replace cat = 1 if p0==1 & p1==1
    replace cat = 2 if p0==0 & p1==1
    replace cat = 3 if p0==1 & p1==0
    drop if missing(cat)
    gen str32 categoria = "1 Intensivo"  if cat==1
    replace  categoria = "2 Nuevos"      if cat==2
    replace  categoria = "3 Salen"       if cat==3
    collapse (sum) contrib=delta v0=valor`t0' v1=valor`t1' (count) n=delta, ///
             by(categoria)
    gen double umbral = `umbral'
    gen int t0 = `t0'
    gen int t1 = `t1'
    egen double _tt = total(contrib)
    gen double share = 100*contrib/_tt
    drop _tt
    replace contrib = contrib/1e6
    replace v0 = v0/1e6
    replace v1 = v1/1e6
    order t0 t1 umbral categoria n v0 v1 contrib share
    save "`out'", replace
end

*--------------------------------------------------------------
* r_superv : supervivencia de subpartidas por cohorte de entrada
* Entrada en c = activa en c y ausente en c-1. Duracion continua:
* el primer anio sin presencia cierra el episodio.
*--------------------------------------------------------------
cap program drop r_superv
program define r_superv
    syntax , IN(string) COHORTE(int) YMIN(int) YMAX(int) UMBRAL(real) OUT(string)
    use "`in'", clear
    keep if inrange(anio,`ymin',`ymax')
    collapse (sum) valor, by(hs6 anio)
    gen byte act = valor > `umbral'
    keep hs6 anio act valor
    reshape wide act valor, i(hs6) j(anio)
    forvalues y = `ymin'/`ymax' {
        cap confirm variable act`y'
        if _rc {
            gen byte act`y' = 0
            gen double valor`y' = 0
        }
        replace act`y'   = 0 if missing(act`y')
        replace valor`y' = 0 if missing(valor`y')
    }
    local cm1 = `cohorte' - 1
    keep if act`cohorte'==1 & act`cm1'==0
    gen byte vivo = 1
    tempname M
    postfile `M' int cohorte int anio int n_vivas double valor_musd using "`out'", replace
    forvalues y = `cohorte'/`ymax' {
        replace vivo = 0 if act`y'==0
        qui count if vivo==1
        local nv = r(N)
        qui summ valor`y' if vivo==1, meanonly
        local vv = cond(r(N)==0, 0, r(sum)/1e6)
        post `M' (`cohorte') (`y') (`nv') (`vv')
    }
    postclose `M'
end

*--------------------------------------------------------------
* r_cms : participacion constante de mercado (3 efectos)
* Requiere un archivo con anio, hs6, valor y la variable mercado
* que toma valores "PAN" y "WLD".
*--------------------------------------------------------------
cap program drop r_cms
program define r_cms
    syntax , IN(string) T0(int) T1(int) OUT(string)
    use "`in'", clear
    keep if inlist(anio,`t0',`t1')
    collapse (sum) valor, by(mercado hs6 anio)
    reshape wide valor, i(mercado hs6) j(anio)
    replace valor`t0' = 0 if missing(valor`t0')
    replace valor`t1' = 0 if missing(valor`t1')
    reshape wide valor`t0' valor`t1', i(hs6) j(mercado) string
    foreach v of varlist valor* {
        replace `v' = 0 if missing(`v')
    }
    * tasas de crecimiento
    qui summ valor`t0'WLD, meanonly
    local W0 = r(sum)
    qui summ valor`t1'WLD, meanonly
    local W1 = r(sum)
    local gw = `W1'/`W0' - 1
    gen double gwk = cond(valor`t0'WLD>0, valor`t1'WLD/valor`t0'WLD - 1, .)
    gen double gpk = cond(valor`t0'PAN>0, valor`t1'PAN/valor`t0'PAN - 1, .)
    gen double e_escala = `gw' * valor`t0'PAN
    gen double e_compos = cond(missing(gwk), 0, (gwk - `gw') * valor`t0'PAN)
    gen double e_compet = cond(missing(gwk) | missing(gpk), 0, (gpk - gwk) * valor`t0'PAN)
    gen double e_nuevos = cond(valor`t0'PAN==0, valor`t1'PAN, 0)
    gen double delta    = valor`t1'PAN - valor`t0'PAN
    collapse (sum) delta e_escala e_compos e_compet e_nuevos
    gen double residuo = delta - e_escala - e_compos - e_compet - e_nuevos
    foreach v of varlist delta e_* residuo {
        replace `v' = `v'/1e6
    }
    gen int t0 = `t0'
    gen int t1 = `t1'
    save "`out'", replace
end

*--------------------------------------------------------------
* r_simil : indice de similitud de canastas (Finger-Kreinin)
* Compara la estructura HS6 de dos grupos definidos por `cvar'.
*--------------------------------------------------------------
cap program drop r_simil
program define r_simil
    syntax , IN(string) CVAR(string) A(string) B(string) BY(string) OUT(string)
    use "`in'", clear
    keep if `cvar'=="`a'" | `cvar'=="`b'"
    collapse (sum) valor, by(`by' `cvar' hs6)
    bysort `by' `cvar': egen double _tot = total(valor)
    gen double sh = valor/_tot
    keep `by' `cvar' hs6 sh
    reshape wide sh, i(`by' hs6) j(`cvar') string
    replace sh`a' = 0 if missing(sh`a')
    replace sh`b' = 0 if missing(sh`b')
    gen double _mn = min(sh`a', sh`b')
    collapse (sum) fk=_mn (count) n_hs6=_mn, by(`by')
    replace fk = 100*fk
    label var fk "Indice Finger-Kreinin (0 = canastas disjuntas, 100 = identicas)"
    save "`out'", replace
end

*--------------------------------------------------------------
* r_gl : comercio intraindustrial Grubel-Lloyd
* Entrada: archivo con anio, nivel de agregacion `nivel', y las
* variables x (exportaciones) y m (importaciones), ambas en USD.
* Devuelve el indice simple y el ajustado por desbalance (Aquino).
*--------------------------------------------------------------
cap program drop r_gl
program define r_gl
    syntax , IN(string) NIVEL(string) OUT(string) [ETIQUETA(string)]
    use "`in'", clear
    collapse (sum) x m, by(anio `nivel')
    replace x = 0 if missing(x)
    replace m = 0 if missing(m)
    drop if x==0 & m==0
    * Indice simple
    gen double _num = abs(x - m)
    gen double _den = x + m
    * Ajuste de Aquino: reescala cada flujo para eliminar el desbalance
    * agregado, que de otro modo deprime mecanicamente el indice.
    bysort anio: egen double _X = total(x)
    bysort anio: egen double _M = total(m)
    gen double xa = x * (_X + _M)/(2*_X) if _X>0
    gen double ma = m * (_X + _M)/(2*_M) if _M>0
    replace xa = 0 if missing(xa)
    replace ma = 0 if missing(ma)
    gen double _numa = abs(xa - ma)
    collapse (sum) _num _den _numa (count) n_lineas=_num, by(anio)
    gen double gl        = 100*(1 - _num/_den)
    gen double gl_aquino = 100*(1 - _numa/_den)
    gen str24 nivel = "`nivel'"
    gen str40 variante = "`etiqueta'"
    keep anio nivel variante n_lineas gl gl_aquino
    order anio variante nivel n_lineas gl gl_aquino
    save "`out'", replace
end

*--------------------------------------------------------------
* r_tci : complementariedad comercial (Michaely / Trade Complementarity)
* Entrada: archivo con anio, hs6, sx (participacion en exportaciones
* del pais exportador al mundo) y sm (participacion en importaciones
* del pais importador desde el mundo).
* 100 = estructuras identicas, 0 = ninguna coincidencia.
*--------------------------------------------------------------
cap program drop r_tci
program define r_tci
    syntax , IN(string) OUT(string) [ETIQUETA(string)]
    use "`in'", clear
    replace sx = 0 if missing(sx)
    replace sm = 0 if missing(sm)
    gen double _d = abs(sm - sx)
    collapse (sum) _d (count) n_hs6=_d, by(anio)
    gen double tci = 100*(1 - _d/2)
    gen str40 variante = "`etiqueta'"
    keep anio variante n_hs6 tci
    save "`out'", replace
end
