#lang racket

; GLSL code generation.  Currently targeting GLSL 1.3 because I can't
; figure out how to switch Racket into 3.3-core.  (Requesting a non-legacy
; GL context crashes.)

(provide node->glsl)

(require "../core/model.rkt")
(require "../core/math.rkt")
(require "../core/compiler/lower.rkt")

(define (wrap str)
  (string-append "(" str ")"))

(define (fn name . args)
  (string-append name "(" (string-join args ", ") ")"))

(define (glsl-vec3 x y z)
  (apply fn "vec3" (map number->string (map real->double-flonum (list x y z)))))

(define/match (glsl-quat q)
  [((quat s (vec3 x y z)))
   (apply fn "vec4"
          (map number->string (map real->double-flonum (list x y z s))))])

(define (glsl-proj v sym)
  (string-append (wrap v) "." (symbol->string sym)))

(define (bin op a b)
  (string-append (wrap a) " " op " " (wrap b)))

(define (decl t r v)
  (string-append t " r" (number->string r) " = " (glsl-expr v) ";"))

; Generates a GLSL expression from an expression-level intermediate.
(define (glsl-expr form)
  (match form
    [(list 'r n) (string-append "r" (number->string n))]
    [(list 'cv (list x y z)) (glsl-vec3 x y z)]
    [(list 'cv (vec3 x y z)) (glsl-vec3 x y z)]
    [(list 'cq q) (glsl-quat q)]
    [(list 'cs x) (number->string (real->double-flonum x))]

    [(list 'sub _ a b) (bin "-" (glsl-expr a) (glsl-expr b))]
    [(list 'add _ a b) (bin "+" (glsl-expr a) (glsl-expr b))]
    [(list 'mul _ a b) (bin "*" (glsl-expr a) (glsl-expr b))]
    [(list 'length _ v) (fn "length" (glsl-expr v))]
    [(list 'dot _ a b) (fn "dot" (glsl-expr a) (glsl-expr b))]

    [(list 'abs a) (fn "abs" (glsl-expr a))]
    [(list 'max a b) (fn "max" (glsl-expr a) (glsl-expr b))]
    [(list 'min a b) (fn "min" (glsl-expr a) (glsl-expr b))]
    [(list 'smin s a b) (fn "smin" (glsl-expr s) (glsl-expr a) (glsl-expr b))]
    [(list 'mod a b) (fn "mod" (glsl-expr a) (glsl-expr b))]
    [(list 'qrot q v) (fn "qrot" (glsl-expr q) (glsl-expr v))]
    [(list 'box c p) (fn "dfBox" (glsl-expr c) (glsl-expr p))]
    [(list 'sphere r p) (fn "dfSphere" (glsl-expr r) (glsl-expr p))]
    [(list 'vec3 a b) (fn "vec3" (glsl-expr a) (glsl-expr b))]
    [(list 'vec3 a b c) (fn "vec3" (glsl-expr a) (glsl-expr b) (glsl-expr c))]
    [(list 'proj _ v sym) (glsl-proj (glsl-expr v) sym)]
    [_ (error "bad expression passed to glsl-expr: " form)]))

(define (glsl-stmt form)
  (match form
    [(list 'assigns r v) (decl "float" r v)]
    [(list 'assignv r v) (decl "vec3" r v)]
    [_ (error "bad statement passed to glsl-stmt: " form)]))

(define (node->glsl n)
  (let-values ([(r s) (generate-statements n)])
    (append (list "float distanceField(vec3 r0) {")
            (map (lambda (st) (string-append "  " (glsl-stmt st)))
                 s)
            (list (string-append "  return r" (number->string r) ";"))
            (list "}")
            )))