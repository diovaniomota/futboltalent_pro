// Shared location data extracted from the club registration flow.
// Keep this file aligned with registro_club_widget.dart so all flows expose the same states/cities.

String locationToApiCountryName(String name) {
  final input = name.trim();
  final map = <String, String>{
    'España': 'Spain',
    'Espana': 'Spain',
    'México': 'Mexico',
    'Mexico': 'Mexico',
    'Brasil': 'Brazil',
    'Alemania': 'Germany',
    'Francia': 'France',
    'Italia': 'Italy',
    'Países Bajos': 'Netherlands',
    'Paises Bajos': 'Netherlands',
    'Holanda': 'Netherlands',
    'Bélgica': 'Belgium',
    'Belgica': 'Belgium',
    'Suiza': 'Switzerland',
    'Suecia': 'Sweden',
    'Noruega': 'Norway',
    'Dinamarca': 'Denmark',
    'Finlandia': 'Finland',
    'Polonia': 'Poland',
    'Grecia': 'Greece',
    'Turquía': 'Turkey',
    'Turquia': 'Turkey',
    'Rusia': 'Russia',
    'Ucrania': 'Ukraine',
    'Rumania': 'Romania',
    'Rumanía': 'Romania',
    'Hungría': 'Hungary',
    'Hungria': 'Hungary',
    'República Checa': 'Czech Republic',
    'Republica Checa': 'Czech Republic',
    'Croacia': 'Croatia',
    'Reino Unido': 'United Kingdom',
    'Irlanda': 'Ireland',
    'Escocia': 'Scotland',
    'Estados Unidos': 'United States',
    'EE.UU.': 'United States',
    'EEUU': 'United States',
    'Canadá': 'Canada',
    'Canada': 'Canada',
    'Colombia': 'Colombia',
    'Venezuela': 'Venezuela',
    'Chile': 'Chile',
    'Perú': 'Peru',
    'Peru': 'Peru',
    'Ecuador': 'Ecuador',
    'Bolivia': 'Bolivia',
    'Paraguay': 'Paraguay',
    'Uruguay': 'Uruguay',
    'Costa Rica': 'Costa Rica',
    'Guatemala': 'Guatemala',
    'Honduras': 'Honduras',
    'El Salvador': 'El Salvador',
    'Nicaragua': 'Nicaragua',
    'Panamá': 'Panama',
    'Panama': 'Panama',
    'Cuba': 'Cuba',
    'República Dominicana': 'Dominican Republic',
    'Republica Dominicana': 'Dominican Republic',
    'Puerto Rico': 'Puerto Rico',
    'Marruecos': 'Morocco',
    'Argelia': 'Algeria',
    'Túnez': 'Tunisia',
    'Tunez': 'Tunisia',
    'Egipto': 'Egypt',
    'Nigeria': 'Nigeria',
    'Ghana': 'Ghana',
    'Senegal': 'Senegal',
    'Costa de Marfil': "Côte d'Ivoire",
    'Camerún': 'Cameroon',
    'Camerun': 'Cameroon',
    'Sudáfrica': 'South Africa',
    'Sudafrica': 'South Africa',
    'Japón': 'Japan',
    'Japon': 'Japan',
    'Corea del Sur': 'South Korea',
    'Arabia Saudita': 'Saudi Arabia',
    'Emiratos Árabes': 'United Arab Emirates',
    'Emiratos Arabes': 'United Arab Emirates',
  };
  return map[input] ?? input;
}

const Map<String, List<String>> kHardcodedStates = {
  'Nicaragua': [
    'Boaco',
    'Carazo',
    'Chinandega',
    'Chontales',
    'Estelí',
    'Granada',
    'Jinotega',
    'León',
    'Madriz',
    'Managua',
    'Masaya',
    'Matagalpa',
    'Nueva Segovia',
    'Rivas',
    'Río San Juan',
    'Costa Caribe Norte',
    'Costa Caribe Sur'
  ],
  'Argentina': [
    'Buenos Aires',
    'Catamarca',
    'Chaco',
    'Chubut',
    'Ciudad Autónoma de Buenos Aires',
    'Córdoba',
    'Corrientes',
    'Entre Ríos',
    'Formosa',
    'Jujuy',
    'La Pampa',
    'La Rioja',
    'Mendoza',
    'Misiones',
    'Neuquén',
    'Río Negro',
    'Salta',
    'San Juan',
    'San Luis',
    'Santa Cruz',
    'Santa Fe',
    'Santiago del Estero',
    'Tierra del Fuego',
    'Tucumán'
  ],
  'Brazil': [
    'Acre',
    'Alagoas',
    'Amapá',
    'Amazonas',
    'Bahia',
    'Ceará',
    'Distrito Federal',
    'Espírito Santo',
    'Goiás',
    'Maranhão',
    'Mato Grosso',
    'Mato Grosso do Sul',
    'Minas Gerais',
    'Pará',
    'Paraíba',
    'Paraná',
    'Pernambuco',
    'Piauí',
    'Rio de Janeiro',
    'Rio Grande do Norte',
    'Rio Grande do Sul',
    'Rondônia',
    'Roraima',
    'Santa Catarina',
    'São Paulo',
    'Sergipe',
    'Tocantins'
  ],
  'México': [
    'Aguascalientes',
    'Baja California',
    'Baja California Sur',
    'Campeche',
    'Chiapas',
    'Chihuahua',
    'Ciudad de México',
    'Coahuila',
    'Colima',
    'Durango',
    'Estado de México',
    'Guanajuato',
    'Guerrero',
    'Hidalgo',
    'Jalisco',
    'Michoacán',
    'Morelos',
    'Nayarit',
    'Nuevo León',
    'Oaxaca',
    'Puebla',
    'Querétaro',
    'Quintana Roo',
    'San Luis Potosí',
    'Sinaloa',
    'Sonora',
    'Tabasco',
    'Tamaulipas',
    'Tlaxcala',
    'Veracruz',
    'Yucatán',
    'Zacatecas'
  ],
  'Colombia': [
    'Amazonas',
    'Antioquia',
    'Arauca',
    'Archipiélago de San Andrés',
    'Atlántico',
    'Bogotá D.C.',
    'Bolívar',
    'Boyacá',
    'Caldas',
    'Caquetá',
    'Casanare',
    'Cauca',
    'Cesar',
    'Chocó',
    'Córdoba',
    'Cundinamarca',
    'Guainía',
    'Guaviare',
    'Huila',
    'La Guajira',
    'Magdalena',
    'Meta',
    'Nariño',
    'Norte de Santander',
    'Putumayo',
    'Quindío',
    'Risaralda',
    'Santander',
    'Sucre',
    'Tolima',
    'Valle del Cauca',
    'Vaupés',
    'Vichada'
  ],
  'Venezuela': [
    'Amazonas',
    'Anzoátegui',
    'Apure',
    'Aragua',
    'Barinas',
    'Bolívar',
    'Carabobo',
    'Cojedes',
    'Delta Amacuro',
    'Distrito Capital',
    'Falcón',
    'Guárico',
    'Lara',
    'Mérida',
    'Miranda',
    'Monagas',
    'Nueva Esparta',
    'Portuguesa',
    'Sucre',
    'Táchira',
    'Trujillo',
    'Vargas',
    'Yaracuy',
    'Zulia'
  ],
  'Chile': [
    'Arica y Parinacota',
    'Tarapacá',
    'Antofagasta',
    'Atacama',
    'Coquimbo',
    'Valparaíso',
    'Región Metropolitana de Santiago',
    'O\'Higgins',
    'Maule',
    'Ñuble',
    'Biobío',
    'La Araucanía',
    'Los Ríos',
    'Los Lagos',
    'Aysén',
    'Magallanes'
  ],
  'Perú': [
    'Amazonas',
    'Áncash',
    'Apurímac',
    'Arequipa',
    'Ayacucho',
    'Cajamarca',
    'Callao',
    'Cusco',
    'Huancavelica',
    'Huánuco',
    'Ica',
    'Junín',
    'La Libertad',
    'Lambayeque',
    'Lima',
    'Loreto',
    'Madre de Dios',
    'Moquegua',
    'Pasco',
    'Piura',
    'Puno',
    'San Martín',
    'Tacna',
    'Tumbes',
    'Ucayali'
  ],
  'Ecuador': [
    'Azuay',
    'Bolívar',
    'Cañar',
    'Carchi',
    'Chimborazo',
    'Cotopaxi',
    'El Oro',
    'Esmeraldas',
    'Galápagos',
    'Guayas',
    'Imbabura',
    'Loja',
    'Los Ríos',
    'Manabí',
    'Morona Santiago',
    'Napo',
    'Orellana',
    'Pastaza',
    'Pichincha',
    'Santa Elena',
    'Santo Domingo de los Tsáchilas',
    'Sucumbíos',
    'Tungurahua',
    'Zamora Chinchipe'
  ],
  'Bolivia': [
    'Beni',
    'Chuquisaca',
    'Cochabamba',
    'La Paz',
    'Oruro',
    'Pando',
    'Potosí',
    'Santa Cruz',
    'Tarija'
  ],
  'Paraguay': [
    'Alto Paraguay',
    'Alto Paraná',
    'Amambay',
    'Asunción',
    'Boquerón',
    'Caaguazú',
    'Caazapá',
    'Canindeyú',
    'Central',
    'Concepción',
    'Cordillera',
    'Guairá',
    'Itapúa',
    'Misiones',
    'Ñeembucú',
    'Paraguarí',
    'Presidente Hayes',
    'San Pedro'
  ],
  'Uruguay': [
    'Artigas',
    'Canelones',
    'Cerro Largo',
    'Colonia',
    'Durazno',
    'Flores',
    'Florida',
    'Lavalleja',
    'Maldonado',
    'Montevideo',
    'Paysandú',
    'Río Negro',
    'Rivera',
    'Rocha',
    'Salto',
    'San José',
    'Soriano',
    'Tacuarembó',
    'Treinta y Tres'
  ],
  'España': [
    'Álava',
    'Albacete',
    'Alicante',
    'Almería',
    'Asturias',
    'Ávila',
    'Badajoz',
    'Baleares',
    'Barcelona',
    'Burgos',
    'Cáceres',
    'Cádiz',
    'Cantabria',
    'Castellón',
    'Ceuta',
    'Ciudad Real',
    'Córdoba',
    'Cuenca',
    'Girona',
    'Granada',
    'Guadalajara',
    'Guipúzcoa',
    'Huelva',
    'Huesca',
    'Jaén',
    'La Coruña',
    'La Rioja',
    'Las Palmas',
    'León',
    'Lleida',
    'Lugo',
    'Madrid',
    'Málaga',
    'Melilla',
    'Murcia',
    'Navarra',
    'Ourense',
    'Palencia',
    'Pontevedra',
    'Salamanca',
    'Santa Cruz de Tenerife',
    'Segovia',
    'Sevilla',
    'Soria',
    'Tarragona',
    'Teruel',
    'Toledo',
    'Valencia',
    'Valladolid',
    'Vizcaya',
    'Zamora',
    'Zaragoza'
  ],
  'Portugal': [
    'Aveiro',
    'Beja',
    'Braga',
    'Bragança',
    'Castelo Branco',
    'Coimbra',
    'Évora',
    'Faro',
    'Guarda',
    'Leiria',
    'Lisboa',
    'Portalegre',
    'Porto',
    'Santarém',
    'Setúbal',
    'Viana do Castelo',
    'Vila Real',
    'Viseu',
    'Açores',
    'Madeira'
  ],
  'Costa Rica': [
    'Alajuela',
    'Cartago',
    'Guanacaste',
    'Heredia',
    'Limón',
    'Puntarenas',
    'San José'
  ],
  'Guatemala': [
    'Alta Verapaz',
    'Baja Verapaz',
    'Chimaltenango',
    'Chiquimula',
    'El Progreso',
    'Escuintla',
    'Guatemala',
    'Huehuetenango',
    'Izabal',
    'Jalapa',
    'Jutiapa',
    'Petén',
    'Quetzaltenango',
    'Quiché',
    'Retalhuleu',
    'Sacatepéquez',
    'San Marcos',
    'Santa Rosa',
    'Sololá',
    'Suchitepéquez',
    'Totonicapán',
    'Zacapa'
  ],
  'Honduras': [
    'Atlántida',
    'Choluteca',
    'Colón',
    'Comayagua',
    'Copán',
    'Cortés',
    'El Paraíso',
    'Francisco Morazán',
    'Gracias a Dios',
    'Intibucá',
    'Islas de la Bahía',
    'La Paz',
    'Lempira',
    'Ocotepeque',
    'Olancho',
    'Santa Bárbara',
    'Valle',
    'Yoro'
  ],
  'El Salvador': [
    'Ahuachapán',
    'Cabañas',
    'Chalatenango',
    'Cuscatlán',
    'La Libertad',
    'La Paz',
    'La Unión',
    'Morazán',
    'San Miguel',
    'San Salvador',
    'San Vicente',
    'Santa Ana',
    'Sonsonate',
    'Usulután'
  ],
  'Panamá': [
    'Bocas del Toro',
    'Chiriquí',
    'Coclé',
    'Colón',
    'Darién',
    'Emberá',
    'Guna Yala',
    'Herrera',
    'Los Santos',
    'Ngöbe-Buglé',
    'Panamá',
    'Panamá Oeste',
    'Veraguas'
  ],
  'República Dominicana': [
    'Azua',
    'Bahoruco',
    'Barahona',
    'Dajabón',
    'Distrito Nacional',
    'Duarte',
    'El Seibo',
    'Elías Piña',
    'Espaillat',
    'Hato Mayor',
    'Hermanas Mirabal',
    'Independencia',
    'La Altagracia',
    'La Romana',
    'La Vega',
    'María Trinidad Sánchez',
    'Moca',
    'Monseñor Nouel',
    'Monte Cristi',
    'Monte Plata',
    'Pedernales',
    'Peravia',
    'Puerto Plata',
    'Samaná',
    'Sánchez Ramírez',
    'San Cristóbal',
    'San José de Ocoa',
    'San Juan',
    'San Pedro de Macorís',
    'Santiago',
    'Santiago Rodríguez',
    'Santo Domingo',
    'Valverde'
  ],
  'United States': [
    'Alabama',
    'Alaska',
    'Arizona',
    'Arkansas',
    'California',
    'Colorado',
    'Connecticut',
    'Delaware',
    'Florida',
    'Georgia',
    'Hawaii',
    'Idaho',
    'Illinois',
    'Indiana',
    'Iowa',
    'Kansas',
    'Kentucky',
    'Louisiana',
    'Maine',
    'Maryland',
    'Massachusetts',
    'Michigan',
    'Minnesota',
    'Mississippi',
    'Missouri',
    'Montana',
    'Nebraska',
    'Nevada',
    'New Hampshire',
    'New Jersey',
    'New Mexico',
    'New York',
    'North Carolina',
    'North Dakota',
    'Ohio',
    'Oklahoma',
    'Oregon',
    'Pennsylvania',
    'Rhode Island',
    'South Carolina',
    'South Dakota',
    'Tennessee',
    'Texas',
    'Utah',
    'Vermont',
    'Virginia',
    'Washington',
    'West Virginia',
    'Wisconsin',
    'Wyoming'
  ],
  'Germany': [
    'Baden-Württemberg',
    'Bavaria',
    'Berlin',
    'Brandenburg',
    'Bremen',
    'Hamburg',
    'Hesse',
    'Lower Saxony',
    'Mecklenburg-Vorpommern',
    'North Rhine-Westphalia',
    'Rhineland-Palatinate',
    'Saarland',
    'Saxony',
    'Saxony-Anhalt',
    'Schleswig-Holstein',
    'Thuringia'
  ],
  'France': [
    'Auvergne-Rhône-Alpes',
    'Bourgogne-Franche-Comté',
    'Bretagne',
    'Centre-Val de Loire',
    'Corse',
    'Grand Est',
    'Hauts-de-France',
    'Île-de-France',
    'Normandie',
    'Nouvelle-Aquitaine',
    'Occitanie',
    'Pays de la Loire',
    'Provence-Alpes-Côte d\'Azur'
  ],
  'Italy': [
    'Abruzzo',
    'Basilicata',
    'Calabria',
    'Campania',
    'Emilia-Romagna',
    'Friuli-Venezia Giulia',
    'Lazio',
    'Liguria',
    'Lombardia',
    'Marche',
    'Molise',
    'Piemonte',
    'Puglia',
    'Sardegna',
    'Sicilia',
    'Toscana',
    'Trentino-Alto Adige',
    'Umbria',
    'Valle d\'Aosta',
    'Veneto'
  ],
  'United Kingdom': ['England', 'Northern Ireland', 'Scotland', 'Wales'],
  'Mexico': [
    'Aguascalientes',
    'Baja California',
    'Baja California Sur',
    'Campeche',
    'Chiapas',
    'Chihuahua',
    'Ciudad de México',
    'Coahuila',
    'Colima',
    'Durango',
    'Estado de México',
    'Guanajuato',
    'Guerrero',
    'Hidalgo',
    'Jalisco',
    'Michoacán',
    'Morelos',
    'Nayarit',
    'Nuevo León',
    'Oaxaca',
    'Puebla',
    'Querétaro',
    'Quintana Roo',
    'San Luis Potosí',
    'Sinaloa',
    'Sonora',
    'Tabasco',
    'Tamaulipas',
    'Tlaxcala',
    'Veracruz',
    'Yucatán',
    'Zacatecas'
  ],
  'Peru': [
    'Amazonas',
    'Áncash',
    'Apurímac',
    'Arequipa',
    'Ayacucho',
    'Cajamarca',
    'Callao',
    'Cusco',
    'Huancavelica',
    'Huánuco',
    'Ica',
    'Junín',
    'La Libertad',
    'Lambayeque',
    'Lima',
    'Loreto',
    'Madre de Dios',
    'Moquegua',
    'Pasco',
    'Piura',
    'Puno',
    'San Martín',
    'Tacna',
    'Tumbes',
    'Ucayali'
  ],
  'Panama': [
    'Bocas del Toro',
    'Chiriquí',
    'Coclé',
    'Colón',
    'Darién',
    'Emberá',
    'Guna Yala',
    'Herrera',
    'Los Santos',
    'Ngöbe-Buglé',
    'Panamá',
    'Panamá Oeste',
    'Veraguas'
  ],
};

const Map<String, List<String>> kHardcodedCities = {
  // Nicaragua
  'Nicaragua|Managua': [
    'Managua',
    'Ciudad Sandino',
    'Ticuantepe',
    'El Crucero',
    'Mateare',
    'Villa El Carmen',
    'San Rafael del Sur'
  ],
  'Nicaragua|Masaya': [
    'Masaya',
    'Nindirí',
    'La Concepción',
    'Tisma',
    'Nandasmo',
    'Niquinohomo',
    'San Juan de Oriente',
    'Catarina'
  ],
  'Nicaragua|Granada': ['Granada', 'Diriomo', 'Diriá', 'Nandaime'],
  'Nicaragua|León': [
    'León',
    'Nagarote',
    'La Paz Centro',
    'Telica',
    'El Sauce',
    'Malpaisillo',
    'Quezalguaque',
    'Santa Rosa del Peñón',
    'Larreynaga',
    'Achuapa'
  ],
  'Nicaragua|Chinandega': [
    'Chinandega',
    'Corinto',
    'El Viejo',
    'Posoltega',
    'Chichigalpa',
    'Puerto Morazán',
    'Villanueva',
    'Somotillo',
    'El Realejo',
    'Santo Tomás del Norte'
  ],
  'Nicaragua|Estelí': [
    'Estelí',
    'Condega',
    'Pueblo Nuevo',
    'La Trinidad',
    'San Juan de Limay',
    'San Nicolás'
  ],
  'Nicaragua|Matagalpa': [
    'Matagalpa',
    'Ciudad Darío',
    'Sébaco',
    'San Ramón',
    'Río Blanco',
    'Muy Muy',
    'Rancho Grande',
    'Tuma La Dalia'
  ],
  'Nicaragua|Carazo': [
    'Jinotepe',
    'Diriamba',
    'San Marcos',
    'Dolores',
    'El Rosario',
    'La Conquista',
    'La Paz de Carazo',
    'Santa Teresa'
  ],
  'Nicaragua|Rivas': [
    'Rivas',
    'San Juan del Sur',
    'Tola',
    'Cárdenas',
    'Buenos Aires',
    'Altagracia',
    'Belén',
    'Moyogalpa',
    'San Jorge'
  ],
  'Nicaragua|Chontales': [
    'Juigalpa',
    'Acoyapa',
    'La Libertad',
    'Comalapa',
    'Cuapa',
    'Villa Sandino',
    'El Coral',
    'Santo Tomás',
    'San Pedro de Lóvago',
    'Santo Domingo'
  ],
  'Nicaragua|Boaco': [
    'Boaco',
    'Camoapa',
    'Teustepe',
    'San José de los Remates',
    'San Lorenzo',
    'Santa Lucía'
  ],
  'Nicaragua|Nueva Segovia': [
    'Ocotal',
    'Jalapa',
    'Mozonte',
    'Dipilto',
    'El Jícaro',
    'Macuelizo',
    'Murra',
    'Quilalí',
    'Santa María',
    'Wiwilí de Nueva Segovia'
  ],
  'Nicaragua|Jinotega': [
    'Jinotega',
    'San Sebastián de Yalí',
    'El Cuá',
    'Wiwilí de Jinotega',
    'San José de Bocay',
    'La Concordia',
    'Santa María de Pantasma'
  ],
  'Nicaragua|Madriz': [
    'Somoto',
    'Palacagüina',
    'San Lucas',
    'Totogalpa',
    'Telpaneca',
    'San Juan de Río Coco',
    'Las Sabanas',
    'Yalagüina'
  ],
  'Nicaragua|Río San Juan': [
    'San Carlos',
    'El Castillo',
    'Morrito',
    'El Almendro',
    'San Miguelito'
  ],
  'Nicaragua|Costa Caribe Norte': [
    'Bilwi',
    'Waspam',
    'Siuna',
    'Rosita',
    'Bonanza',
    'Prinzapolka',
    'Mulukukú'
  ],
  'Nicaragua|Costa Caribe Sur': [
    'Bluefields',
    'El Rama',
    'Nueva Guinea',
    'Pearl Lagoon',
    'Bocana de Paiwas',
    'La Cruz del Río Grande',
    'Laguna de Perlas',
    'Muelle de los Bueyes',
    'Desembocadura del Río Grande'
  ],
  // Argentina
  'Argentina|Buenos Aires': [
    'La Plata',
    'Mar del Plata',
    'Quilmes',
    'Lomas de Zamora',
    'Lanús',
    'Almirante Brown',
    'Florencio Varela',
    'General San Martín',
    'Tres de Febrero',
    'Morón',
    'Tigre',
    'Avellaneda',
    'Berazategui',
    'Vicente López',
    'San Isidro',
    'Bahía Blanca',
    'Tandil',
    'Mar del Plata',
    'Olavarría',
    'Necochea',
    'Junín',
    'Pergamino',
    'Azul',
    'Chivilcoy'
  ],
  'Argentina|Ciudad Autónoma de Buenos Aires': [
    'Buenos Aires',
    'Palermo',
    'Belgrano',
    'Flores',
    'Caballito',
    'Recoleta',
    'San Telmo',
    'La Boca',
    'Almagro',
    'Villa Crespo',
    'Núñez',
    'Saavedra'
  ],
  'Argentina|Córdoba': [
    'Córdoba',
    'Villa Carlos Paz',
    'Río Cuarto',
    'San Francisco',
    'Villa María',
    'Alta Gracia',
    'Jesús María',
    'La Calera',
    'Cosquín',
    'Río Tercero'
  ],
  'Argentina|Santa Fe': [
    'Rosario',
    'Santa Fe',
    'Rafaela',
    'Venado Tuerto',
    'Reconquista',
    'Santo Tomé',
    'Villa Constitución',
    'San Lorenzo'
  ],
  'Argentina|Mendoza': [
    'Mendoza',
    'Godoy Cruz',
    'Guaymallén',
    'Las Heras',
    'Maipú',
    'San Rafael',
    'Luján de Cuyo',
    'Rivadavia'
  ],
  'Argentina|Tucumán': [
    'San Miguel de Tucumán',
    'Tafí Viejo',
    'Concepción',
    'Yerba Buena',
    'Banda del Río Salí'
  ],
  'Argentina|Salta': [
    'Salta',
    'Tartagal',
    'Orán',
    'Metán',
    'General Güemes',
    'Rosario de la Frontera'
  ],
  'Argentina|Entre Ríos': [
    'Paraná',
    'Concordia',
    'Gualeguaychú',
    'Concepción del Uruguay',
    'Villaguay'
  ],
  'Argentina|Corrientes': [
    'Corrientes',
    'Goya',
    'Paso de los Libres',
    'Mercedes',
    'Curuzú Cuatiá'
  ],
  'Argentina|Chaco': [
    'Resistencia',
    'Barranqueras',
    'Presidencia Roque Sáenz Peña',
    'Villa Ángela',
    'Quitilipi'
  ],
  'Argentina|Misiones': [
    'Posadas',
    'Oberá',
    'Eldorado',
    'Puerto Iguazú',
    'Apóstoles'
  ],
  'Argentina|Jujuy': [
    'San Salvador de Jujuy',
    'Palpalá',
    'La Quiaca',
    'Humahuaca'
  ],
  'Argentina|Santiago del Estero': [
    'Santiago del Estero',
    'La Banda',
    'Termas de Río Hondo',
    'Añatuya'
  ],
  'Argentina|San Juan': [
    'San Juan',
    'Rivadavia',
    'Rawson',
    'Pocito',
    'Chimbas'
  ],
  'Argentina|Neuquén': [
    'Neuquén',
    'Cipolletti',
    'San Martín de los Andes',
    'Zapala',
    'Cutral-Có',
    'Centenario'
  ],
  'Argentina|Río Negro': [
    'Viedma',
    'General Roca',
    'San Carlos de Bariloche',
    'Cipolletti',
    'El Bolsón'
  ],
  'Argentina|La Rioja': ['La Rioja', 'Chilecito', 'Aimogasta'],
  'Argentina|San Luis': ['San Luis', 'Villa Mercedes', 'Merlo'],
  'Argentina|Catamarca': [
    'San Fernando del Valle de Catamarca',
    'Andalgalá',
    'Belén',
    'Santa María'
  ],
  'Argentina|La Pampa': ['Santa Rosa', 'General Pico', 'Realicó'],
  'Argentina|Chubut': [
    'Comodoro Rivadavia',
    'Rawson',
    'Puerto Madryn',
    'Trelew',
    'Esquel'
  ],
  'Argentina|Santa Cruz': [
    'Río Gallegos',
    'Caleta Olivia',
    'Pico Truncado',
    'Las Heras',
    'Puerto Deseado'
  ],
  'Argentina|Tierra del Fuego': ['Ushuaia', 'Río Grande', 'Tolhuin'],
  'Argentina|Formosa': ['Formosa', 'Clorinda', 'Pirané'],
  // Brazil
  'Brazil|São Paulo': [
    'São Paulo',
    'Guarulhos',
    'Campinas',
    'São Bernardo do Campo',
    'Santo André',
    'Osasco',
    'Ribeirão Preto',
    'São José dos Campos',
    'Sorocaba',
    'Santos',
    'Mauá',
    'Diadema',
    'Jundiaí',
    'Carapicuíba',
    'Piracicaba',
    'Bauru',
    'São José do Rio Preto',
    'Mogi das Cruzes',
    'Franca'
  ],
  'Brazil|Rio de Janeiro': [
    'Rio de Janeiro',
    'São Gonçalo',
    'Duque de Caxias',
    'Nova Iguaçu',
    'Niterói',
    'Belford Roxo',
    'São João de Meriti',
    'Campos dos Goytacazes',
    'Petrópolis',
    'Volta Redonda',
    'Macaé',
    'Itaboraí'
  ],
  'Brazil|Minas Gerais': [
    'Belo Horizonte',
    'Uberlândia',
    'Contagem',
    'Juiz de Fora',
    'Betim',
    'Montes Claros',
    'Ribeirão das Neves',
    'Uberaba',
    'Governador Valadares',
    'Ipatinga'
  ],
  'Brazil|Bahia': [
    'Salvador',
    'Feira de Santana',
    'Vitória da Conquista',
    'Camaçari',
    'Juazeiro',
    'Ilhéus',
    'Lauro de Freitas',
    'Itabuna'
  ],
  'Brazil|Rio Grande do Sul': [
    'Porto Alegre',
    'Caxias do Sul',
    'Canoas',
    'Pelotas',
    'Santa Maria',
    'Novo Hamburgo',
    'São Leopoldo',
    'Gravataí',
    'Viamão',
    'Passo Fundo'
  ],
  'Brazil|Paraná': [
    'Curitiba',
    'Londrina',
    'Maringá',
    'Ponta Grossa',
    'Cascavel',
    'Foz do Iguaçu',
    'São José dos Pinhais',
    'Colombo',
    'Guarapuava'
  ],
  'Brazil|Santa Catarina': [
    'Florianópolis',
    'Joinville',
    'Blumenau',
    'São José',
    'Chapecó',
    'Criciúma',
    'Itajaí',
    'Jaraguá do Sul',
    'Palhoça'
  ],
  'Brazil|Pernambuco': [
    'Recife',
    'Caruaru',
    'Olinda',
    'Paulista',
    'Petrolina',
    'Jaboatão dos Guararapes',
    'Caruaru',
    'Camaragibe'
  ],
  'Brazil|Ceará': [
    'Fortaleza',
    'Juazeiro do Norte',
    'Caucaia',
    'Maracanaú',
    'Sobral',
    'Crato',
    'Itapipoca'
  ],
  'Brazil|Goiás': [
    'Goiânia',
    'Aparecida de Goiânia',
    'Anápolis',
    'Rio Verde',
    'Luziânia',
    'Águas Lindas de Goiás'
  ],
  'Brazil|Amazonas': [
    'Manaus',
    'Parintins',
    'Itacoatiara',
    'Manacapuru',
    'Coari'
  ],
  'Brazil|Pará': [
    'Belém',
    'Ananindeua',
    'Santarém',
    'Marabá',
    'Castanhal',
    'Parauapebas'
  ],
  'Brazil|Maranhão': [
    'São Luís',
    'Imperatriz',
    'São José de Ribamar',
    'Timon',
    'Caxias'
  ],
  'Brazil|Mato Grosso do Sul': [
    'Campo Grande',
    'Dourados',
    'Três Lagoas',
    'Corumbá',
    'Ponta Porã'
  ],
  'Brazil|Mato Grosso': [
    'Cuiabá',
    'Várzea Grande',
    'Rondonópolis',
    'Sinop',
    'Cáceres'
  ],
  'Brazil|Espírito Santo': [
    'Vitória',
    'Serra',
    'Vila Velha',
    'Cariacica',
    'Cachoeiro de Itapemirim'
  ],
  'Brazil|Alagoas': [
    'Maceió',
    'Arapiraca',
    'Palmeira dos Índios',
    'União dos Palmares'
  ],
  'Brazil|Piauí': ['Teresina', 'Parnaíba', 'Picos', 'Floriano'],
  'Brazil|Rio Grande do Norte': ['Natal', 'Mossoró', 'Parnamirim', 'Caicó'],
  'Brazil|Paraíba': ['João Pessoa', 'Campina Grande', 'Santa Rita', 'Patos'],
  'Brazil|Sergipe': [
    'Aracaju',
    'Nossa Senhora do Socorro',
    'Lagarto',
    'Itabaiana'
  ],
  'Brazil|Rondônia': ['Porto Velho', 'Ji-Paraná', 'Ariquemes', 'Vilhena'],
  'Brazil|Tocantins': ['Palmas', 'Araguaína', 'Gurupi'],
  'Brazil|Amapá': ['Macapá', 'Santana'],
  'Brazil|Roraima': ['Boa Vista'],
  'Brazil|Acre': ['Rio Branco', 'Cruzeiro do Sul'],
  'Brazil|Distrito Federal': [
    'Brasília',
    'Ceilândia',
    'Taguatinga',
    'Samambaia',
    'Planaltina'
  ],
  // Mexico (API name)
  'Mexico|Ciudad de México': [
    'Ciudad de México',
    'Álvaro Obregón',
    'Azcapotzalco',
    'Benito Juárez',
    'Coyoacán',
    'Cuauhtémoc',
    'Gustavo A. Madero',
    'Iztapalapa',
    'Iztacalco',
    'Miguel Hidalgo',
    'Milpa Alta',
    'Tláhuac',
    'Tlalpan',
    'Venustiano Carranza',
    'Xochimilco'
  ],
  'Mexico|Jalisco': [
    'Guadalajara',
    'Zapopan',
    'Tlaquepaque',
    'Tonalá',
    'Tlajomulco de Zúñiga',
    'Puerto Vallarta',
    'Lagos de Moreno',
    'Tepatitlán de Morelos'
  ],
  'Mexico|Nuevo León': [
    'Monterrey',
    'Guadalupe',
    'Apodaca',
    'San Nicolás de los Garza',
    'Escobedo',
    'Santa Catarina',
    'San Pedro Garza García',
    'Linares'
  ],
  'Mexico|Estado de México': [
    'Ecatepec',
    'Naucalpan',
    'Nezahualcóyotl',
    'Chimalhuacán',
    'Toluca',
    'Tlalnepantla',
    'Ixtapaluca',
    'Tecámac',
    'Tultitlán',
    'Cuautitlán Izcalli'
  ],
  'Mexico|Veracruz': [
    'Veracruz',
    'Xalapa',
    'Boca del Río',
    'Coatzacoalcos',
    'Córdoba',
    'Orizaba',
    'Poza Rica',
    'Tuxpan'
  ],
  'Mexico|Puebla': [
    'Puebla',
    'Tehuacán',
    'Atlixco',
    'Cholula',
    'Cuautlancingo'
  ],
  'Mexico|Guanajuato': [
    'León',
    'Irapuato',
    'Celaya',
    'Salamanca',
    'Guanajuato',
    'Silao',
    'San Luis de la Paz'
  ],
  'Mexico|Chihuahua': [
    'Ciudad Juárez',
    'Chihuahua',
    'Delicias',
    'Cuauhtémoc',
    'Parral'
  ],
  'Mexico|Coahuila': [
    'Torreón',
    'Saltillo',
    'Monclova',
    'Piedras Negras',
    'Acuña'
  ],
  'Mexico|Tamaulipas': [
    'Reynosa',
    'Matamoros',
    'Nuevo Laredo',
    'Tampico',
    'Cd. Victoria'
  ],
  'Mexico|Sonora': [
    'Hermosillo',
    'Ciudad Obregón',
    'Nogales',
    'Guaymas',
    'San Luis Río Colorado'
  ],
  'Mexico|Sinaloa': ['Culiacán', 'Mazatlán', 'Ahome (Los Mochis)', 'Guasave'],
  'Mexico|Baja California': [
    'Tijuana',
    'Mexicali',
    'Ensenada',
    'Tecate',
    'Rosarito'
  ],
  'Mexico|Michoacán': [
    'Morelia',
    'Uruapan',
    'Zamora',
    'Lázaro Cárdenas',
    'Apatzingán'
  ],
  'Mexico|Oaxaca': [
    'Oaxaca de Juárez',
    'Juchitán de Zaragoza',
    'Salina Cruz',
    'Tuxtepec'
  ],
  'Mexico|Chiapas': [
    'Tuxtla Gutiérrez',
    'San Cristóbal de las Casas',
    'Tapachula',
    'Comitán'
  ],
  'Mexico|Guerrero': [
    'Acapulco',
    'Chilpancingo',
    'Iguala',
    'Taxco',
    'Zihuatanejo'
  ],
  'Mexico|Hidalgo': ['Pachuca', 'Tulancingo', 'Tizayuca', 'Tula de Allende'],
  'Mexico|Querétaro': ['Querétaro', 'San Juan del Río', 'El Marqués'],
  'Mexico|Yucatán': ['Mérida', 'Valladolid', 'Tizimín', 'Progreso'],
  // Colombia
  'Colombia|Antioquia': [
    'Medellín',
    'Bello',
    'Envigado',
    'Itagüí',
    'Rionegro',
    'Apartadó',
    'Turbo',
    'Caucasia',
    'Sabaneta'
  ],
  'Colombia|Bogotá D.C.': [
    'Bogotá',
    'Suba',
    'Engativá',
    'Kennedy',
    'Usaquén',
    'Chapinero',
    'Fontibón',
    'Bosa'
  ],
  'Colombia|Valle del Cauca': [
    'Cali',
    'Buenaventura',
    'Palmira',
    'Tulúa',
    'Buga',
    'Cartago',
    'Yumbo',
    'Jamundí'
  ],
  'Colombia|Atlántico': [
    'Barranquilla',
    'Soledad',
    'Malambo',
    'Sabanalarga',
    'Baranoa'
  ],
  'Colombia|Bolívar': [
    'Cartagena',
    'Magangué',
    'El Carmen de Bolívar',
    'Turbaco',
    'Mompós'
  ],
  'Colombia|Santander': [
    'Bucaramanga',
    'Floridablanca',
    'Girón',
    'Piedecuesta',
    'Barrancabermeja',
    'Socorro'
  ],
  'Colombia|Cundinamarca': [
    'Soacha',
    'Fusagasugá',
    'Zipaquirá',
    'Chía',
    'Mosquera',
    'Facatativá',
    'Madrid',
    'Funza'
  ],
  'Colombia|Norte de Santander': [
    'Cúcuta',
    'Ocaña',
    'Pamplona',
    'Villa del Rosario',
    'Los Patios'
  ],
  'Colombia|Córdoba': [
    'Montería',
    'Cereté',
    'Sahagún',
    'Lorica',
    'Montelíbano'
  ],
  'Colombia|Tolima': ['Ibagué', 'Espinal', 'Melgar', 'El Guamo', 'Honda'],
  'Colombia|Nariño': ['Pasto', 'Tumaco', 'Ipiales', 'Túquerres'],
  'Colombia|Huila': ['Neiva', 'Pitalito', 'Garzón', 'La Plata'],
  'Colombia|Magdalena': [
    'Santa Marta',
    'Ciénaga',
    'El Banco',
    'Fundación',
    'Plato'
  ],
  'Colombia|Caldas': [
    'Manizales',
    'Villamaría',
    'La Dorada',
    'Chinchiná',
    'Riosucio'
  ],
  'Colombia|Risaralda': [
    'Pereira',
    'Dosquebradas',
    'Santa Rosa de Cabal',
    'La Virginia'
  ],
  'Colombia|Quindío': ['Armenia', 'Calarcá', 'Montenegro', 'Quimbaya'],
  'Colombia|Meta': ['Villavicencio', 'Granada', 'Acacías', 'Puerto López'],
  'Colombia|Cauca': [
    'Popayán',
    'Santander de Quilichao',
    'Puerto Tejada',
    'Guapi'
  ],
  'Colombia|Sucre': ['Sincelejo', 'Corozal', 'Sampués', 'Tolú'],
  'Colombia|Cesar': [
    'Valledupar',
    'Aguachica',
    'Bosconia',
    'La Paz',
    'Codazzi'
  ],
  'Colombia|La Guajira': ['Riohacha', 'Maicao', 'Uribia', 'Manaure'],
  'Colombia|Boyacá': ['Tunja', 'Duitama', 'Sogamoso', 'Chiquinquirá', 'Nobsa'],
  // Venezuela
  'Venezuela|Distrito Capital': ['Caracas'],
  'Venezuela|Miranda': [
    'Los Teques',
    'Guarenas',
    'Guatire',
    'Ocumare del Tuy',
    'Santa Teresa del Tuy',
    'Charallave',
    'Cúa'
  ],
  'Venezuela|Carabobo': [
    'Valencia',
    'Puerto Cabello',
    'Guacara',
    'San Diego',
    'Los Guayos',
    'Naguanagua',
    'Mariara'
  ],
  'Venezuela|Aragua': [
    'Maracay',
    'Turmero',
    'La Victoria',
    'Cagua',
    'El Limón',
    'Villa de Cura'
  ],
  'Venezuela|Lara': [
    'Barquisimeto',
    'Carora',
    'El Tocuyo',
    'Quibor',
    'Chivacoa'
  ],
  'Venezuela|Zulia': [
    'Maracaibo',
    'Cabimas',
    'Ciudad Ojeda',
    'San Francisco',
    'Lagunillas',
    'Punto Fijo (Falcón)',
    'Machiques'
  ],
  'Venezuela|Bolívar': [
    'Ciudad Bolívar',
    'Ciudad Guayana',
    'San Félix',
    'Puerto Ordaz',
    'Upata',
    'Caicara del Orinoco'
  ],
  'Venezuela|Anzoátegui': [
    'Barcelona',
    'Lecherías',
    'El Tigre',
    'Puerto La Cruz',
    'Anaco',
    'Guanta'
  ],
  'Venezuela|Sucre': ['Cumaná', 'Carúpano', 'Güiria', 'Maturín'],
  'Venezuela|Táchira': [
    'San Cristóbal',
    'Táriba',
    'Rubio',
    'San Antonio del Táchira',
    'La Fría'
  ],
  'Venezuela|Mérida': ['Mérida', 'El Vigía', 'Tovar', 'Barinas'],
  'Venezuela|Monagas': ['Maturín', 'Caripito', 'Punta de Mata'],
  'Venezuela|Falcón': [
    'Coro',
    'Punto Fijo',
    'La Vela de Coro',
    'Chichiriviche'
  ],
  'Venezuela|Portuguesa': ['Guanare', 'Acarigua', 'Araure', 'Guanarito'],
  'Venezuela|Barinas': ['Barinas', 'Barinitas', 'Socopó'],
  'Venezuela|Guárico': [
    'San Juan de los Morros',
    'Calabozo',
    'Valle de la Pascua',
    'Zaraza'
  ],
  'Venezuela|Yaracuy': ['San Felipe', 'Chivacoa', 'Nirgua', 'Independencia'],
  'Venezuela|Cojedes': ['San Carlos', 'Tinaquillo', 'El Tinaco'],
  'Venezuela|Nueva Esparta': [
    'La Asunción',
    'Porlamar',
    'Pampatar',
    'Juangriego'
  ],
  // Chile
  'Chile|Región Metropolitana de Santiago': [
    'Santiago',
    'Maipú',
    'La Florida',
    'Puente Alto',
    'Las Condes',
    'Ñuñoa',
    'Quilicura',
    'San Bernardo',
    'Peñalolén',
    'La Pintana',
    'Renca',
    'Pudahuel',
    'Estación Central'
  ],
  'Chile|Valparaíso': [
    'Valparaíso',
    'Viña del Mar',
    'Quilpué',
    'San Antonio',
    'Villa Alemana',
    'Quillota',
    'Los Andes',
    'Rancagua'
  ],
  'Chile|Biobío': [
    'Concepción',
    'Talcahuano',
    'San Pedro de la Paz',
    'Hualpén',
    'Chillán',
    'Los Ángeles',
    'Coronel',
    'Lota'
  ],
  'Chile|La Araucanía': [
    'Temuco',
    'Padre Las Casas',
    'Villarrica',
    'Angol',
    'Pucon'
  ],
  'Chile|Los Lagos': ['Puerto Montt', 'Osorno', 'Castro', 'Puerto Varas'],
  'Chile|Antofagasta': ['Antofagasta', 'Calama', 'Tocopilla', 'Mejillones'],
  'Chile|Atacama': ['Copiapó', 'Vallenar', 'Caldera'],
  'Chile|Coquimbo': ['La Serena', 'Coquimbo', 'Ovalle', 'Illapel'],
  'Chile|O\'Higgins': ['Rancagua', 'San Fernando', 'Pichilemu', 'Graneros'],
  'Chile|Maule': ['Talca', 'Curicó', 'Linares', 'Constitución'],
  'Chile|Los Ríos': ['Valdivia', 'La Unión', 'Río Bueno'],
  'Chile|Tarapacá': ['Iquique', 'Alto Hospicio'],
  'Chile|Arica y Parinacota': ['Arica', 'Putre'],
  'Chile|Aysén': ['Coyhaique', 'Puerto Aysén'],
  'Chile|Magallanes': ['Punta Arenas', 'Puerto Natales', 'Puerto Williams'],
  // Peru
  'Peru|Lima': [
    'Lima',
    'Callao',
    'San Juan de Lurigancho',
    'San Martín de Porres',
    'Ate',
    'Comas',
    'Villa El Salvador',
    'Los Olivos',
    'Puente Piedra',
    'San Juan de Miraflores',
    'Villa María del Triunfo',
    'Carabayllo',
    'Chorrillos',
    'Independencia',
    'El Agustino'
  ],
  'Peru|Arequipa': [
    'Arequipa',
    'Cayma',
    'Cerro Colorado',
    'Socabaya',
    'Paucarpata',
    'Yanahuara'
  ],
  'Peru|La Libertad': [
    'Trujillo',
    'Chimbote',
    'Huanchaco',
    'El Porvenir',
    'La Esperanza',
    'Florencia de Mora'
  ],
  'Peru|Piura': [
    'Piura',
    'Sullana',
    'Castilla',
    'Talara',
    'Paita',
    'Chulucanas'
  ],
  'Peru|Cusco': ['Cusco', 'San Sebastián', 'Wanchaq', 'Santiago', 'Sicuani'],
  'Peru|Junín': ['Huancayo', 'El Tambo', 'Chilca', 'Satipo', 'Tarma'],
  'Peru|Áncash': ['Huaraz', 'Chimbote', 'Nuevo Chimbote', 'Huari'],
  'Peru|Lambayeque': [
    'Chiclayo',
    'José Leonardo Ortiz',
    'La Victoria',
    'Ferreñafe',
    'Lambayeque'
  ],
  'Peru|Ica': ['Ica', 'Chincha Alta', 'Pisco', 'Nazca'],
  'Peru|Loreto': ['Iquitos', 'Yurimaguas', 'Nauta'],
  'Peru|Puno': ['Puno', 'Juliaca', 'Ilave', 'Ayaviri'],
  'Peru|Cajamarca': ['Cajamarca', 'Jaén', 'Chota'],
  'Peru|San Martín': ['Tarapoto', 'Moyobamba', 'Juanjuí'],
  'Peru|Ucayali': ['Pucallpa', 'Aguaytía'],
  'Peru|Huánuco': ['Huánuco', 'Leoncio Prado', 'Tingo María'],
  'Peru|Madre de Dios': ['Puerto Maldonado'],
  'Peru|Ayacucho': ['Ayacucho', 'Huamanga'],
  'Peru|Apurímac': ['Abancay', 'Andahuaylalas'],
  'Peru|Pasco': ['Cerro de Pasco', 'Yanacancha'],
  'Peru|Moquegua': ['Moquegua', 'Ilo'],
  'Peru|Tacna': ['Tacna', 'Ciudad Nueva'],
  'Peru|Tumbes': ['Tumbes', 'Aguas Verdes'],
  // Ecuador
  'Ecuador|Pichincha': [
    'Quito',
    'Cayambe',
    'Sangolquí',
    'Machachi',
    'Santo Domingo'
  ],
  'Ecuador|Guayas': [
    'Guayaquil',
    'Durán',
    'Milagro',
    'Samborondón',
    'Playas',
    'Daule'
  ],
  'Ecuador|Azuay': ['Cuenca', 'Gualaceo', 'Paute', 'Sígsig'],
  'Ecuador|Manabí': [
    'Portoviejo',
    'Manta',
    'Chone',
    'El Carmen',
    'Bahía de Caráquez'
  ],
  'Ecuador|El Oro': ['Machala', 'Pasaje', 'Santa Rosa', 'Huaquillas'],
  'Ecuador|Los Ríos': ['Quevedo', 'Babahoyo', 'Vinces', 'Ventanas'],
  'Ecuador|Tungurahua': ['Ambato', 'Baños', 'Pelileo', 'Píllaro'],
  'Ecuador|Chimborazo': ['Riobamba', 'Guano', 'Alausí'],
  'Ecuador|Imbabura': ['Ibarra', 'Otavalo', 'Cotacachi', 'Antonio Ante'],
  'Ecuador|Esmeraldas': ['Esmeraldas', 'Atacames', 'Quinindé'],
  'Ecuador|Loja': ['Loja', 'Catamayo', 'Cariamanga'],
  'Ecuador|Cotopaxi': ['Latacunga', 'La Maná', 'Salcedo'],
  'Ecuador|Carchi': ['Tulcán', 'Montúfar'],
  'Ecuador|Bolívar': ['Guaranda', 'San Miguel'],
  'Ecuador|Santo Domingo de los Tsáchilas': ['Santo Domingo'],
  'Ecuador|Santa Elena': ['Santa Elena', 'La Libertad', 'Salinas'],
  'Ecuador|Sucumbíos': ['Nueva Loja (Lago Agrio)', 'Shushufindi'],
  'Ecuador|Orellana': ['Puerto Francisco de Orellana', 'Loreto'],
  'Ecuador|Galápagos': ['Puerto Ayora', 'Puerto Baquerizo Moreno'],
  // Bolivia
  'Bolivia|La Paz': [
    'La Paz',
    'El Alto',
    'Viacha',
    'Achacachi',
    'Copacabana',
    'Caranavi'
  ],
  'Bolivia|Santa Cruz': [
    'Santa Cruz de la Sierra',
    'Montero',
    'Warnes',
    'Yapacaní',
    'Camiri',
    'Cotoca'
  ],
  'Bolivia|Cochabamba': [
    'Cochabamba',
    'Sacaba',
    'Quillacollo',
    'Tiquipaya',
    'Colcapirhua',
    'Punata'
  ],
  'Bolivia|Oruro': ['Oruro', 'Llallagua', 'Huanuni'],
  'Bolivia|Potosí': ['Potosí', 'Uyuni', 'Tupiza', 'Villazón'],
  'Bolivia|Chuquisaca': ['Sucre', 'Camargo', 'Monteagudo'],
  'Bolivia|Tarija': ['Tarija', 'Yacuiba', 'Bermejo', 'Entre Ríos'],
  'Bolivia|Beni': ['Trinidad', 'Riberalta', 'Guayaramerín'],
  'Bolivia|Pando': ['Cobija'],
  // Paraguay
  'Paraguay|Central': [
    'Luque',
    'San Lorenzo',
    'Capiatá',
    'Lambaré',
    'Fernando de la Mora',
    'Mariano Roque Alonso',
    'Ñemby',
    'Limpio',
    'Areguá'
  ],
  'Paraguay|Asunción': ['Asunción'],
  'Paraguay|Alto Paraná': [
    'Ciudad del Este',
    'Presidente Franco',
    'Hernandarias',
    'Minga Guazú'
  ],
  'Paraguay|Itapúa': ['Encarnación', 'Fram', 'Coronel Bogado'],
  'Paraguay|Caaguazú': ['Coronel Oviedo', 'Caaguazú', 'Vaquería'],
  'Paraguay|Guairá': ['Villarrica', 'Coronel Martínez', 'Borja'],
  'Paraguay|Paraguarí': ['Paraguarí', 'Carapeguá', 'Yaguarón'],
  'Paraguay|Misiones': [
    'San Juan Bautista',
    'San Ignacio',
    'Santa María de Fe'
  ],
  'Paraguay|Cordillera': ['Caacupé', 'Tobatí', 'San Bernardino'],
  'Paraguay|San Pedro': ['San Pedro del Ycuamandiyú', 'Lima'],
  'Paraguay|Concepción': ['Concepción', 'Horqueta'],
  'Paraguay|Amambay': ['Pedro Juan Caballero', 'Bella Vista'],
  'Paraguay|Alto Paraguay': ['Fuerte Olimpo', 'Carmelo Peralta'],
  'Paraguay|Boquerón': ['Filadelfia', 'Mariscal Estigarribia'],
  'Paraguay|Canindeyú': ['Salto del Guairá', 'Curuguaty'],
  'Paraguay|Caazapá': ['Caazapá', 'San Juan Nepomuceno'],
  'Paraguay|Presidente Hayes': ['Villa Hayes', 'Benjamín Aceval'],
  'Paraguay|Ñeembucú': ['Pilar', 'Paso de Patria'],
  // Uruguay
  'Uruguay|Montevideo': [
    'Montevideo',
    'Ciudad Vieja',
    'Pocitos',
    'Punta Carretas',
    'Malvín',
    'Carrasco',
    'Prado'
  ],
  'Uruguay|Canelones': [
    'Las Piedras',
    'La Paz',
    'Pando',
    'Progreso',
    'Santa Lucía',
    'Toledo'
  ],
  'Uruguay|Maldonado': [
    'Maldonado',
    'Punta del Este',
    'San Carlos',
    'Piriápolis'
  ],
  'Uruguay|Salto': ['Salto', 'Constitución'],
  'Uruguay|Paysandú': ['Paysandú', 'Quebracho'],
  'Uruguay|Rivera': ['Rivera', 'Tranqueras'],
  'Uruguay|Colonia': ['Colonia del Sacramento', 'Juan Lacaze', 'Carmelo'],
  'Uruguay|San José': ['San José de Mayo', 'Ciudad del Plata'],
  'Uruguay|Tacuarembó': ['Tacuarembó', 'Paso de los Toros'],
  'Uruguay|Durazno': ['Durazno', 'Carmen'],
  'Uruguay|Rocha': ['Rocha', 'La Paloma', 'Chuy'],
  'Uruguay|Soriano': ['Mercedes', 'Dolores'],
  'Uruguay|Florida': ['Florida', 'Sarandí Grande'],
  'Uruguay|Río Negro': ['Fray Bentos', 'Young'],
  'Uruguay|Artigas': ['Artigas', 'Tomás Gomensoro'],
  'Uruguay|Cerro Largo': ['Melo', 'Río Branco'],
  'Uruguay|Treinta y Tres': ['Treinta y Tres', 'Vergara'],
  'Uruguay|Lavalleja': ['Minas', 'Solís de Mataojo'],
  'Uruguay|Flores': ['Trinidad'],
  // Spain
  'Spain|Madrid': [
    'Madrid',
    'Móstoles',
    'Alcalá de Henares',
    'Fuenlabrada',
    'Leganés',
    'Getafe',
    'Alcorcón',
    'Torrejón de Ardoz',
    'Parla',
    'Alcobendas',
    'Pozuelo de Alarcón',
    'Rivas-Vaciamadrid'
  ],
  'Spain|Barcelona': [
    'Barcelona',
    'L\'Hospitalet de Llobregat',
    'Badalona',
    'Terrassa',
    'Sabadell',
    'Mataró',
    'Santa Coloma de Gramenet',
    'Cornellà de Llobregat',
    'Sant Boi de Llobregat',
    'Rubí',
    'Castelldefels',
    'Gavà'
  ],
  'Spain|Valencia': [
    'Valencia',
    'Alicante',
    'Elche',
    'Torrent',
    'Mislata',
    'Castellón de la Plana',
    'Alcoy',
    'Orihuela',
    'Gandia'
  ],
  'Spain|Sevilla': [
    'Sevilla',
    'Dos Hermanas',
    'Alcalá de Guadaíra',
    'Jerez de la Frontera',
    'Utrera',
    'Mairena del Aljarafe'
  ],
  'Spain|Málaga': [
    'Málaga',
    'Marbella',
    'Fuengirola',
    'Torremolinos',
    'Vélez-Málaga',
    'Estepona'
  ],
  'Spain|Murcia': [
    'Murcia',
    'Cartagena',
    'Lorca',
    'Molina de Segura',
    'Alcantarilla'
  ],
  'Spain|Bilbao': ['Bilbao', 'Barakaldo', 'Getxo', 'Basauri'],
  'Spain|Vizcaya': ['Bilbao', 'Barakaldo', 'Getxo', 'Basauri', 'Portugalete'],
  'Spain|Guipúzcoa': ['San Sebastián', 'Irun', 'Errenteria', 'Zarautz'],
  'Spain|Zaragoza': [
    'Zaragoza',
    'Calatayud',
    'Utebo',
    'Ejea de los Caballeros'
  ],
  'Spain|Alicante': ['Alicante', 'Elche', 'Torrevieja', 'Benidorm', 'Orihuela'],
  'Spain|Granada': ['Granada', 'Motril', 'Almuñécar', 'Guadix'],
  'Spain|Córdoba': ['Córdoba', 'Lucena', 'Cabra', 'Montoro'],
  'Spain|La Coruña': ['A Coruña', 'Santiago de Compostela', 'Ferrol', 'Lugo'],
  'Spain|Asturias': ['Oviedo', 'Gijón', 'Avilés', 'Mieres'],
  'Spain|Cantabria': ['Santander', 'Torrelavega', 'Camargo', 'Piélagos'],
  'Spain|Navarra': ['Pamplona', 'Tudela', 'Burlada', 'Barañáin'],
  'Spain|La Rioja': ['Logroño', 'Calahorra', 'Arnedo', 'Haro'],
  'Spain|Castilla y León (León)': [
    'León',
    'Ponferrada',
    'San Andrés del Rabanedo'
  ],
  'Spain|Castilla y León (Valladolid)': [
    'Valladolid',
    'Medina del Campo',
    'Aranda de Duero'
  ],
  'Spain|Castilla y León (Burgos)': ['Burgos', 'Miranda de Ebro'],
  'Spain|Castilla y León (Salamanca)': ['Salamanca', 'Béjar', 'Ciudad Rodrigo'],
  'Spain|Castilla-La Mancha': [
    'Toledo',
    'Albacete',
    'Ciudad Real',
    'Cuenca',
    'Guadalajara',
    'Talavera de la Reina'
  ],
  'Spain|Extremadura': ['Badajoz', 'Cáceres', 'Mérida', 'Don Benito'],
  'Spain|Galicia': [
    'Vigo',
    'A Coruña',
    'Santiago de Compostela',
    'Ourense',
    'Lugo',
    'Pontevedra'
  ],
  'Spain|Pontevedra': [
    'Vigo',
    'Pontevedra',
    'Vilagarcía de Arousa',
    'Redondela'
  ],
  'Spain|Baleares': ['Palma', 'Ibiza', 'Maó', 'Manacor'],
  'Spain|Las Palmas': [
    'Las Palmas de Gran Canaria',
    'Telde',
    'Arrecife',
    'Puerto del Rosario'
  ],
  'Spain|Santa Cruz de Tenerife': [
    'Santa Cruz de Tenerife',
    'San Cristóbal de La Laguna',
    'Arona',
    'Adeje'
  ],
  // Portugal
  'Portugal|Lisboa': [
    'Lisboa',
    'Sintra',
    'Cascais',
    'Loures',
    'Odivelas',
    'Amadora',
    'Almada',
    'Setúbal',
    'Seixal',
    'Barreiro',
    'Montijo'
  ],
  'Portugal|Porto': [
    'Porto',
    'Vila Nova de Gaia',
    'Matosinhos',
    'Gondomar',
    'Maia',
    'Valongo',
    'Braga',
    'Guimarães'
  ],
  'Portugal|Braga': [
    'Braga',
    'Guimarães',
    'Barcelos',
    'Famalicão',
    'Vila Verde'
  ],
  'Portugal|Setúbal': ['Setúbal', 'Almada', 'Seixal', 'Barreiro', 'Sesimbra'],
  'Portugal|Aveiro': [
    'Aveiro',
    'Oliveira de Azeméis',
    'São João da Madeira',
    'Ovar',
    'Espinho'
  ],
  'Portugal|Faro': ['Faro', 'Loulé', 'Portimão', 'Lagos', 'Tavira', 'Olhão'],
  'Portugal|Coimbra': ['Coimbra', 'Figueira da Foz', 'Cantanhede', 'Lousã'],
  'Portugal|Leiria': ['Leiria', 'Marinha Grande', 'Caldas da Rainha', 'Nazaré'],
  'Portugal|Santarém': ['Santarém', 'Tomar', 'Torres Novas', 'Entroncamento'],
  'Portugal|Viseu': ['Viseu', 'Lamego', 'Mangualde'],
  'Portugal|Castelo Branco': ['Castelo Branco', 'Covilhã', 'Fundão'],
  'Portugal|Guarda': ['Guarda', 'Seia', 'Gouveia'],
  'Portugal|Viana do Castelo': [
    'Viana do Castelo',
    'Ponte de Lima',
    'Esposende'
  ],
  'Portugal|Vila Real': ['Vila Real', 'Chaves', 'Peso da Régua'],
  'Portugal|Bragança': ['Bragança', 'Mirandela', 'Macedo de Cavaleiros'],
  'Portugal|Évora': ['Évora', 'Estremoz', 'Reguengos de Monsaraz'],
  'Portugal|Portalegre': ['Portalegre', 'Elvas', 'Ponte de Sor'],
  'Portugal|Beja': ['Beja', 'Moura', 'Serpa'],
  'Portugal|Açores': ['Ponta Delgada', 'Angra do Heroísmo', 'Horta'],
  'Portugal|Madeira': ['Funchal', 'Câmara de Lobos', 'São Vicente'],
  // Costa Rica
  'Costa Rica|San José': [
    'San José',
    'Desamparados',
    'Alajuelita',
    'Aserrí',
    'Curridabat',
    'Tibás',
    'Goicoechea',
    'Moravia',
    'Escazú',
    'Santa Ana'
  ],
  'Costa Rica|Alajuela': [
    'Alajuela',
    'San Carlos',
    'Grecia',
    'Atenas',
    'Naranjo',
    'Palmares',
    'Poás',
    'Upala'
  ],
  'Costa Rica|Cartago': [
    'Cartago',
    'El Guarco',
    'La Unión',
    'Turrialba',
    'Oreamuno',
    'Paraíso'
  ],
  'Costa Rica|Heredia': [
    'Heredia',
    'San Rafael',
    'Santa Bárbara',
    'Belén',
    'Flores',
    'San Isidro',
    'Sarapiquí'
  ],
  'Costa Rica|Guanacaste': [
    'Liberia',
    'Nicoya',
    'Santa Cruz',
    'Cañas',
    'Bagaces',
    'Carrillo',
    'La Cruz'
  ],
  'Costa Rica|Puntarenas': [
    'Puntarenas',
    'Quepos',
    'Golfito',
    'Osa',
    'Aguirre'
  ],
  'Costa Rica|Limón': [
    'Limón',
    'Pococí',
    'Siquirres',
    'Talamanca',
    'Matina',
    'Guácimo'
  ],
  // Guatemala
  'Guatemala|Guatemala': [
    'Guatemala City',
    'Mixco',
    'Villa Nueva',
    'San Juan Sacatepéquez',
    'Chinautla',
    'Petapa',
    'Villa Canales'
  ],
  'Guatemala|Quetzaltenango': [
    'Quetzaltenango',
    'Coatepeque',
    'San Marcos',
    'Huehuetenango'
  ],
  'Guatemala|Escuintla': ['Escuintla', 'Mazatenango', 'Puerto San José'],
  'Guatemala|Alta Verapaz': ['Cobán', 'Chisec', 'Panzós'],
  'Guatemala|Izabal': ['Puerto Barrios', 'Morales', 'Livingston'],
  'Guatemala|Suchitepéquez': ['Mazatenango', 'Cuyotenango', 'Retalhuleu'],
  'Guatemala|San Marcos': ['San Marcos', 'Quetzaltenango', 'Malacatán'],
  'Guatemala|Petén': ['Flores', 'Santa Elena', 'San Benito'],
  'Guatemala|Chimaltenango': [
    'Chimaltenango',
    'Tecpán',
    'San Martín Jilotepeque'
  ],
  'Guatemala|Sacatepéquez': [
    'Antigua Guatemala',
    'Jocotenango',
    'Ciudad Vieja'
  ],
  // Honduras
  'Honduras|Francisco Morazán': [
    'Tegucigalpa',
    'Comayagüela',
    'San Pedro Sula',
    'Valle de Ángeles',
    'Santa Lucía'
  ],
  'Honduras|Cortés': [
    'San Pedro Sula',
    'Puerto Cortés',
    'Villanueva',
    'Choloma',
    'La Lima'
  ],
  'Honduras|Atlántida': ['La Ceiba', 'El Progreso', 'Tela', 'La Masica'],
  'Honduras|Yoro': ['Yoro', 'El Progreso', 'Santa Rita', 'Olanchito'],
  'Honduras|Santa Bárbara': ['Santa Bárbara', 'Santa Rosa de Copán'],
  'Honduras|Choluteca': ['Choluteca', 'El Triunfo'],
  'Honduras|Olancho': ['Juticalpa', 'Catacamas'],
  'Honduras|Colón': ['Trujillo', 'Tocoa', 'Sonaguera'],
  'Honduras|Copán': ['Santa Rosa de Copán', 'Copán Ruinas', 'La Entrada'],
  'Honduras|Comayagua': ['Comayagua', 'Siguatepeque'],
  'Honduras|El Paraíso': ['Danlí', 'El Paraíso', 'Yuscarán'],
  // El Salvador
  'El Salvador|San Salvador': [
    'San Salvador',
    'Soyapango',
    'Mejicanos',
    'Apopa',
    'Ciudad Delgado',
    'Santa Tecla',
    'Antiguo Cuscatlán',
    'Ilopango',
    'San Marcos',
    'San Martín'
  ],
  'El Salvador|Santa Ana': [
    'Santa Ana',
    'Ahuachapán',
    'Chalchuapa',
    'Coatepeque'
  ],
  'El Salvador|San Miguel': ['San Miguel', 'Ciudad Barrios', 'Usulután'],
  'El Salvador|La Libertad': [
    'Santa Tecla',
    'Antiguo Cuscatlán',
    'Quezaltepeque',
    'Zaragoza',
    'La Libertad'
  ],
  'El Salvador|Sonsonate': ['Sonsonate', 'Acajutla', 'Armenia', 'Izalco'],
  'El Salvador|Usulután': ['Usulután', 'Jiquilisco', 'San Francisco Javier'],
  'El Salvador|Cuscatlán': ['Cojutepeque', 'Suchitoto', 'San Pedro Perulapán'],
  'El Salvador|Chalatenango': ['Chalatenango', 'La Palma', 'Nueva Concepción'],
  'El Salvador|La Paz': ['Zacatecoluca', 'San Luis Talpa', 'Olocuilta'],
  'El Salvador|Cabañas': ['Sensuntepeque', 'Ilobasco'],
  'El Salvador|Morazán': ['San Francisco Gotera', 'Jocoaitique', 'Corinto'],
  'El Salvador|La Unión': ['La Unión', 'San Alejo', 'Conchagua'],
  'El Salvador|San Vicente': ['San Vicente', 'Tecoluca'],
  'El Salvador|Ahuachapán': ['Ahuachapán', 'Atiquizaya', 'Concepción de Ataco'],
  // Panama
  'Panama|Panamá': [
    'Ciudad de Panamá',
    'San Miguelito',
    'Tocumen',
    'Panamá Oeste',
    'Arraiján',
    'La Chorrera'
  ],
  'Panama|Panamá Oeste': ['La Chorrera', 'Arraiján', 'Capira'],
  'Panama|Colón': ['Colón', 'Portobelo', 'Chagres'],
  'Panama|Chiriquí': ['David', 'Boquete', 'La Concepción', 'Changuinola'],
  'Panama|Coclé': ['Penonomé', 'La Pintada', 'Natá', 'Antón'],
  'Panama|Herrera': ['Chitré', 'Los Santos', 'Parita'],
  'Panama|Los Santos': ['Las Tablas', 'Chitré', 'Macaracas'],
  'Panama|Veraguas': ['Santiago', 'Las Palmas', 'Soná'],
  'Panama|Bocas del Toro': ['Bocas del Toro', 'Changuinola', 'Almirante'],
  'Panama|Darién': ['La Palma', 'Metetí'],
  // Dominican Republic (API name)
  'Dominican Republic|Distrito Nacional': ['Santo Domingo'],
  'Dominican Republic|Santo Domingo': [
    'Santo Domingo Este',
    'Santo Domingo Norte',
    'Santo Domingo Oeste',
    'Boca Chica',
    'San Antonio de Guerra'
  ],
  'Dominican Republic|Santiago': [
    'Santiago de los Caballeros',
    'San José de las Matas',
    'Moca',
    'Licey al Medio'
  ],
  'Dominican Republic|San Cristóbal': [
    'San Cristóbal',
    'Villa Altagracia',
    'Baní'
  ],
  'Dominican Republic|Puerto Plata': [
    'Puerto Plata',
    'Sosúa',
    'Cabarete',
    'Imbert'
  ],
  'Dominican Republic|La Altagracia': [
    'Higüey',
    'San Rafael del Yuma',
    'El Seibo'
  ],
  'Dominican Republic|La Romana': ['La Romana', 'San Pedro de Macorís'],
  'Dominican Republic|Duarte': ['San Francisco de Macorís', 'Tenares'],
  'Dominican Republic|Espaillat': ['Moca', 'Gaspar Hernández'],
  'Dominican Republic|La Vega': ['La Vega', 'Jarabacoa', 'Constanza', 'Bonao'],
  'Dominican Republic|Peravia': ['Baní', 'Nizao'],
  'Dominican Republic|San Pedro de Macorís': [
    'San Pedro de Macorís',
    'Hato Mayor'
  ],
  'Dominican Republic|Valverde': ['Mao', 'Esperanza'],
  // United States (partial)
  'United States|Florida': [
    'Miami',
    'Orlando',
    'Tampa',
    'Jacksonville',
    'St. Petersburg',
    'Hialeah',
    'Tallahassee',
    'Fort Lauderdale',
    'Cape Coral',
    'Pembroke Pines'
  ],
  'United States|California': [
    'Los Angeles',
    'San Diego',
    'San Jose',
    'San Francisco',
    'Fresno',
    'Sacramento',
    'Long Beach',
    'Oakland',
    'Bakersfield',
    'Anaheim'
  ],
  'United States|Texas': [
    'Houston',
    'San Antonio',
    'Dallas',
    'Austin',
    'Fort Worth',
    'El Paso',
    'Arlington',
    'Corpus Christi',
    'Plano',
    'Laredo'
  ],
  'United States|New York': [
    'New York City',
    'Buffalo',
    'Rochester',
    'Yonkers',
    'Syracuse',
    'Albany',
    'New Rochelle',
    'Mount Vernon'
  ],
  'United States|Illinois': [
    'Chicago',
    'Aurora',
    'Naperville',
    'Joliet',
    'Rockford',
    'Springfield',
    'Elgin',
    'Peoria'
  ],
  'United States|Georgia': [
    'Atlanta',
    'Augusta',
    'Columbus',
    'Macon',
    'Savannah',
    'Athens'
  ],
  'United States|North Carolina': [
    'Charlotte',
    'Raleigh',
    'Greensboro',
    'Durham',
    'Winston-Salem',
    'Fayetteville'
  ],
  'United States|Arizona': [
    'Phoenix',
    'Tucson',
    'Mesa',
    'Chandler',
    'Scottsdale',
    'Glendale',
    'Gilbert',
    'Tempe'
  ],
  'United States|Nevada': [
    'Las Vegas',
    'Henderson',
    'Reno',
    'North Las Vegas',
    'Sparks'
  ],
  'United States|Washington': [
    'Seattle',
    'Spokane',
    'Tacoma',
    'Vancouver',
    'Bellevue',
    'Kirkland'
  ],
  'United States|Colorado': [
    'Denver',
    'Colorado Springs',
    'Aurora',
    'Fort Collins',
    'Lakewood',
    'Thornton',
    'Pueblo'
  ],
  'United States|New Jersey': [
    'Newark',
    'Jersey City',
    'Paterson',
    'Elizabeth',
    'Edison',
    'Woodbridge'
  ],
  // Italy
  'Italy|Lombardia': [
    'Milano',
    'Brescia',
    'Bergamo',
    'Monza',
    'Como',
    'Varese',
    'Pavia'
  ],
  'Italy|Lazio': ['Roma', 'Latina', 'Frosinone', 'Viterbo', 'Rieti'],
  'Italy|Campania': [
    'Napoli',
    'Salerno',
    'Torre del Greco',
    'Pozzuoli',
    'Caserta',
    'Benevento'
  ],
  'Italy|Sicilia': [
    'Palermo',
    'Catania',
    'Messina',
    'Siracusa',
    'Ragusa',
    'Agrigento',
    'Trapani'
  ],
  'Italy|Piemonte': [
    'Torino',
    'Novara',
    'Alessandria',
    'Asti',
    'Cuneo',
    'Biella'
  ],
  'Italy|Veneto': [
    'Venezia',
    'Verona',
    'Padova',
    'Vicenza',
    'Treviso',
    'Mestre'
  ],
  'Italy|Emilia-Romagna': [
    'Bologna',
    'Modena',
    'Reggio nell\'Emilia',
    'Parma',
    'Ferrara',
    'Ravenna',
    'Rimini'
  ],
  'Italy|Toscana': ['Firenze', 'Prato', 'Livorno', 'Pisa', 'Arezzo', 'Siena'],
  'Italy|Puglia': ['Bari', 'Taranto', 'Foggia', 'Lecce', 'Brindisi'],
  'Italy|Calabria': ['Reggio Calabria', 'Catanzaro', 'Cosenza', 'Crotone'],
  'Italy|Sardegna': ['Cagliari', 'Sassari', 'Nuoro', 'Oristano'],
  'Italy|Friuli-Venezia Giulia': ['Trieste', 'Udine', 'Pordenone', 'Gorizia'],
  'Italy|Trentino-Alto Adige': ['Trento', 'Bolzano', 'Rovereto'],
  'Italy|Marche': ['Ancona', 'Pesaro', 'Fano', 'Macerata'],
  'Italy|Liguria': ['Genova', 'La Spezia', 'Savona', 'Imperia'],
  'Italy|Abruzzo': ['L\'Aquila', 'Pescara', 'Chieti', 'Teramo'],
  'Italy|Basilicata': ['Potenza', 'Matera'],
  'Italy|Molise': ['Campobasso', 'Isernia'],
  'Italy|Umbria': ['Perugia', 'Terni'],
  'Italy|Valle d\'Aosta': ['Aosta'],
  // Germany
  'Germany|North Rhine-Westphalia': [
    'Köln',
    'Düsseldorf',
    'Dortmund',
    'Essen',
    'Duisburg',
    'Bochum',
    'Wuppertal',
    'Bielefeld',
    'Bonn',
    'Münster',
    'Gelsenkirchen',
    'Aachen'
  ],
  'Germany|Bavaria': [
    'München',
    'Nürnberg',
    'Augsburg',
    'Würzburg',
    'Regensburg',
    'Ingolstadt',
    'Fürth',
    'Erlangen'
  ],
  'Germany|Baden-Württemberg': [
    'Stuttgart',
    'Mannheim',
    'Karlsruhe',
    'Freiburg im Breisgau',
    'Heidelberg',
    'Heilbronn',
    'Ulm'
  ],
  'Germany|Lower Saxony': [
    'Hannover',
    'Braunschweig',
    'Osnabrück',
    'Oldenburg',
    'Göttingen',
    'Wolfsburg'
  ],
  'Germany|Hesse': [
    'Frankfurt am Main',
    'Wiesbaden',
    'Kassel',
    'Darmstadt',
    'Offenbach am Main'
  ],
  'Germany|Saxony': ['Leipzig', 'Dresden', 'Chemnitz', 'Zwickau'],
  'Germany|Berlin': [
    'Berlin',
    'Mitte',
    'Kreuzberg',
    'Prenzlauer Berg',
    'Charlottenburg',
    'Neukölln'
  ],
  'Germany|Hamburg': ['Hamburg', 'Wandsbek', 'Altona', 'Harburg'],
  'Germany|Brandenburg': ['Potsdam', 'Cottbus', 'Brandenburg an der Havel'],
  'Germany|Saxony-Anhalt': ['Halle', 'Magdeburg', 'Dessau-Roßlau'],
  'Germany|Thuringia': ['Erfurt', 'Jena', 'Gera', 'Weimar'],
  'Germany|Rhineland-Palatinate': [
    'Mainz',
    'Ludwigshafen',
    'Koblenz',
    'Trier',
    'Kaiserslautern'
  ],
  'Germany|Saarland': ['Saarbrücken', 'Neunkirchen', 'Völklingen'],
  'Germany|Schleswig-Holstein': ['Kiel', 'Lübeck', 'Flensburg'],
  'Germany|Mecklenburg-Vorpommern': ['Rostock', 'Schwerin', 'Stralsund'],
  'Germany|Bremen': ['Bremen', 'Bremerhaven'],
  // France
  'France|Île-de-France': [
    'Paris',
    'Boulogne-Billancourt',
    'Saint-Denis',
    'Argenteuil',
    'Montreuil',
    'Nanterre',
    'Versailles',
    'Créteil',
    'Vitry-sur-Seine',
    'Colombes'
  ],
  'France|Auvergne-Rhône-Alpes': [
    'Lyon',
    'Grenoble',
    'Saint-Étienne',
    'Villeurbanne',
    'Clermont-Ferrand',
    'Annecy',
    'Chambéry'
  ],
  'France|Nouvelle-Aquitaine': [
    'Bordeaux',
    'Limoges',
    'Pau',
    'La Rochelle',
    'Poitiers',
    'Bayonne'
  ],
  'France|Occitanie': [
    'Toulouse',
    'Montpellier',
    'Nîmes',
    'Narbonne',
    'Perpignan',
    'Carcassonne'
  ],
  'France|Hauts-de-France': [
    'Lille',
    'Amiens',
    'Dunkerque',
    'Roubaix',
    'Tourcoing',
    'Valenciennes'
  ],
  'France|Grand Est': [
    'Strasbourg',
    'Reims',
    'Metz',
    'Nancy',
    'Mulhouse',
    'Colmar'
  ],
  'France|Provence-Alpes-Côte d\'Azur': [
    'Marseille',
    'Nice',
    'Toulon',
    'Aix-en-Provence',
    'Avignon',
    'Cannes',
    'Antibes'
  ],
  'France|Pays de la Loire': [
    'Nantes',
    'Le Mans',
    'Angers',
    'Saint-Nazaire',
    'Laval'
  ],
  'France|Bretagne': ['Rennes', 'Brest', 'Quimper', 'Lorient', 'Vannes'],
  'France|Normandie': ['Rouen', 'Caen', 'Le Havre', 'Cherbourg', 'Évreux'],
  'France|Centre-Val de Loire': [
    'Orléans',
    'Tours',
    'Bourges',
    'Blois',
    'Chartres'
  ],
  'France|Bourgogne-Franche-Comté': [
    'Dijon',
    'Besançon',
    'Belfort',
    'Chalon-sur-Saône'
  ],
  'France|Corse': ['Ajaccio', 'Bastia'],
  // United Kingdom
  'United Kingdom|England': [
    'London',
    'Birmingham',
    'Leeds',
    'Sheffield',
    'Manchester',
    'Liverpool',
    'Bristol',
    'Coventry',
    'Newcastle',
    'Nottingham',
    'Leicester',
    'Southampton',
    'Oxford',
    'Cambridge',
    'Derby',
    'Brighton'
  ],
  'United Kingdom|Scotland': [
    'Glasgow',
    'Edinburgh',
    'Aberdeen',
    'Dundee',
    'Inverness',
    'Stirling'
  ],
  'United Kingdom|Wales': [
    'Cardiff',
    'Swansea',
    'Newport',
    'Bangor',
    'Wrexham'
  ],
  'United Kingdom|Northern Ireland': [
    'Belfast',
    'Londonderry',
    'Lisburn',
    'Armagh'
  ],
};

List<String> getHardcodedStates(String countryName) {
  final requestedApiCountry = locationToApiCountryName(countryName.trim());
  final states = <String>{};
  for (final entry in kHardcodedStates.entries) {
    if (entry.key == countryName ||
        entry.key == requestedApiCountry ||
        locationToApiCountryName(entry.key) == requestedApiCountry) {
      states.addAll(entry.value);
    }
  }
  final list = states.toList()..sort();
  return list;
}

List<String> getHardcodedCities(String countryName, String stateName) {
  final requestedApiCountry = locationToApiCountryName(countryName.trim());
  final requestedState = stateName.trim();
  final cities = <String>{};
  for (final entry in kHardcodedCities.entries) {
    final separatorIndex = entry.key.indexOf('|');
    if (separatorIndex == -1) continue;
    final entryCountry = entry.key.substring(0, separatorIndex);
    final entryState = entry.key.substring(separatorIndex + 1);
    if ((entryCountry == countryName ||
            entryCountry == requestedApiCountry ||
            locationToApiCountryName(entryCountry) == requestedApiCountry) &&
        entryState == requestedState) {
      cities.addAll(entry.value);
    }
  }
  final list = cities.toList()..sort();
  return list;
}

List<String> getHardcodedCitiesForCountry(String countryName) {
  final requestedApiCountry = locationToApiCountryName(countryName.trim());
  final cities = <String>{};
  for (final entry in kHardcodedCities.entries) {
    final separatorIndex = entry.key.indexOf('|');
    if (separatorIndex == -1) continue;
    final entryCountry = entry.key.substring(0, separatorIndex);
    if (entryCountry == countryName ||
        entryCountry == requestedApiCountry ||
        locationToApiCountryName(entryCountry) == requestedApiCountry) {
      cities.addAll(entry.value);
    }
  }
  final list = cities.toList()..sort();
  return list;
}

String _normalizeLocationLookupKey(dynamic value) {
  final text = value?.toString().trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') return '';

  const replacements = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'ã': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
  };

  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(replacements[char] ?? char);
  }
  return buffer.toString();
}

String? _findLocationOption(Iterable<String> options, dynamic value) {
  final requested = _normalizeLocationLookupKey(value);
  if (requested.isEmpty) return null;

  for (final option in options) {
    if (_normalizeLocationLookupKey(option) == requested) {
      return option;
    }
  }
  return null;
}

bool hasHardcodedStatesForCountry(String countryName) =>
    getHardcodedStates(countryName).isNotEmpty;

bool hasHardcodedCitiesForCountry(String countryName) =>
    getHardcodedCitiesForCountry(countryName).isNotEmpty;

String? findHardcodedState(String countryName, String stateName) =>
    _findLocationOption(getHardcodedStates(countryName), stateName);

String? findHardcodedCityForCountry(String countryName, String cityName) =>
    _findLocationOption(getHardcodedCitiesForCountry(countryName), cityName);

String? findHardcodedCityForState(
  String countryName,
  String stateName,
  String cityName,
) =>
    _findLocationOption(
      getHardcodedCities(countryName, stateName),
      cityName,
    );
