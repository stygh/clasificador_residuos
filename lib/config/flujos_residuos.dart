/// Correspondencia entre las categorías del modelo y los flujos de disposición.
///
/// Reproduce la tabla 5 de la memoria. Su validez depende de los materiales
/// aceptados y de los criterios de separación del lugar de uso, por lo que su
/// aplicación en otro municipio exige una revisión específica.
abstract final class FlujosResiduos {
  static const Map<String, String> denominacion = <String, String>{
    'cardboard': 'Cartón',
    'paper': 'Papel',
    'glass': 'Vidrio',
    'metal': 'Metal',
    'organic': 'Orgánico',
    'clothes': 'Textil',
    'shoes': 'Calzado',
    'trash': 'Resto',
  };

  static const Map<String, String> flujo = <String, String>{
    'cardboard': 'Reciclable - papel y cartón',
    'paper': 'Reciclable - papel y cartón',
    'glass': 'Reciclable - vidrio',
    'metal': 'Reciclable - envases metálicos',
    'organic': 'Compostable',
    'clothes': 'Punto limpio - reutilización textil',
    'shoes': 'Punto limpio - reutilización textil',
    'trash': 'Fracción resto - vertedero',
  };

  static String? flujoDe(String categoria) =>
      flujo[categoria.toLowerCase().trim()];
}
