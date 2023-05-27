#include <opencv2/opencv.hpp>

static float _NORMALIZED_FACIAL_LANDMARKS_DATA[468][2] = {
    {0.49066195, 0.7133885},    {0.49042386, 0.52723485},  {0.49050152, 0.6244965},
    {0.45844677, 0.39348277},   {0.4905825, 0.49120593},   {0.49006602, 0.43998772},
    {0.48907965, 0.26775706},   {0.11721139, 0.23243594},  {0.48957095, 0.11063451},
    {0.48949632, 0.03535742},   {0.48905632, -0.25326234}, {0.4907858, 0.73766613},
    {0.49081355, 0.7606857},    {0.4908666, 0.7839426},    {0.49079415, 0.78913504},
    {0.4908271, 0.80801845},    {0.49086872, 0.831855},    {0.49092326, 0.8631041},
    {0.49104446, 0.94170016},   {0.49009967, 0.5546924},   {0.44398275, 0.5741402},
    {-0.2106727, 0.00861922},   {0.2523662, 0.2832579},    {0.2042254, 0.28945392},
    {0.1552372, 0.28322184},    {0.09056008, 0.24730967},  {0.30096018, 0.27277085},
    {0.21548809, 0.16713436},   {0.2595488, 0.17071684},   {0.16957955, 0.17298089},
    {0.13164258, 0.18425746},   {0.043018, 0.28581},       {0.30856833, 1.0507976},
    {0.10015843, 0.22331452},   {-0.20773543, 0.26701325}, {-0.02414621, 0.25144747},
    {0.23481508, 0.5045001},    {0.44063616, 0.7097012},   {0.4449884, 0.762481},
    {0.3840104, 0.7218947},     {0.33943903, 0.73847425},  {0.40284824, 0.76374006},
    {0.36457124, 0.76704985},   {0.26937196, 0.84716266},  {0.46683946, 0.5275276},
    {0.4642676, 0.49167544},    {0.06039319, 0.11509081},  {0.31504983, 0.36394927},
    {0.3660137, 0.52945083},    {0.3509634, 0.50311893},   {0.09496811, 0.5005815},
    {0.46075967, 0.4424029},    {0.20108324, 0.05883435},  {0.12877828, 0.07731954},
    {-0.09675749, -0.09848522}, {0.39672711, 0.09345116},  {0.29908365, 0.18449144},
    {0.23298171, 0.7922538},    {-0.27583498, 0.85219014}, {0.38898414, 0.5723152},
    {0.41446668, 0.59347576},   {0.28167963, 0.7884952},   {0.30013445, 0.7875627},
    {0.09448256, 0.03961415},   {0.3531811, 0.5553779},    {0.2873921, 0.05599196},
    {0.28232294, 0.01076962},   {0.1903341, -0.23029903},  {0.0108011, -0.03099815},
    {0.24915197, -0.10741784},  {0.01047484, 0.08868673},  {-0.08942058, 0.05201372},
    {0.44268388, 0.7376863},    {0.39652622, 0.741894},    {0.35389552, 0.7514722},
    {0.393559, 0.5851372},      {0.2925385, 0.7871472},    {0.31904542, 0.80939215},
    {0.32005206, 0.787085},     {0.4195982, 0.5444628},    {0.3688312, 0.78418756},
    {0.40608776, 0.7841225},    {0.4472093, 0.78405076},   {0.43053833, 0.9379409},
    {0.44192585, 0.8617842},    {0.44321233, 0.82923037},  {0.4432334, 0.80578357},
    {0.44304678, 0.78921837},   {0.36314115, 0.7893578},   {0.36057413, 0.8040033},
    {0.35472178, 0.8187327},    {0.34614718, 0.83330894},  {0.2959003, 0.69076014},
    {-0.37090415, 0.5509728},   {0.4903264, 0.5851119},    {0.3370172, 0.78961957},
    {0.33070365, 0.8010128},    {0.43397966, 0.6231119},   {0.35356513, 0.59569615},
    {0.42509514, 0.6093918},    {0.2635329, 0.39636588},   {0.19704658, 0.43663597},
    {0.33384863, 0.52658314},   {0.03225203, -0.18047164}, {0.11854403, -0.08533629},
    {0.18350407, 0.01215954},   {0.31292278, 0.8845064},   {0.3862302, 0.02093028},
    {0.36480215, -0.1098879},   {0.33342764, -0.2497105},  {0.11592615, 0.2646692},
    {-0.00803981, 0.3294946},   {0.33535972, 0.26431814},  {0.05940344, 0.18766014},
    {0.36188984, 0.33336782},   {0.39879864, 0.50869733},  {-0.07952328, 0.36885905},
    {0.04230375, 0.36800843},   {0.11137532, 0.3864613},   {0.19386435, 0.37397826},
    {0.25749052, 0.34993485},   {0.310977, 0.3240539},     {0.44813582, 0.2762354},
    {-0.06039021, 0.4864401},   {0.00945808, 0.17624807},  {0.4739895, 0.55369264},
    {0.32125092, 0.4170324},    {-0.36162117, 0.27013144}, {0.3592803, 0.3023075},
    {0.30784345, 0.529875},     {0.07601253, 0.22579695},  {0.3824061, 0.47686696},
    {-0.33810768, 0.70034444},  {0.34643772, 0.24336138},  {0.42429656, 0.45338264},
    {0.02854156, 0.939626},     {-0.04352415, 1.0322431},  {-0.20510256, 0.51651907},
    {-0.06969981, 0.8698207},   {-0.1581445, 0.14948419},  {0.2889787, 1.1224228},
    {0.47446907, 0.58377683},   {0.2818322, 0.4586393},    {-0.08708218, 0.2627534},
    {0.16877942, 0.25976214},   {0.21234928, 0.267416},    {0.30676025, 0.81592965},
    {-0.06259334, 0.6009466},   {0.36930662, 1.2302231},   {0.17070079, 1.149443},
    {0.07714309, 1.0989524},    {0.48931465, -0.1052461},  {0.49159575, 1.2484183},
    {0.2527582, 0.26420003},    {0.30066028, 0.25829503},  {0.3310663, 0.25034374},
    {-0.05075949, 0.16421606},  {0.29250854, 0.19938153},  {0.2522571, 0.18826446},
    {0.21220936, 0.18724632},   {0.16866222, 0.19260857},  {0.13789575, 0.2011967},
    {-0.29335994, 0.12383505},  {0.1379709, 0.24424627},   {0.49057597, 0.65296},
    {0.34147182, 0.663431},     {0.3941785, 0.5603462},    {0.43007633, 0.6569765},
    {0.48963526, 0.17996965},   {0.11681002, 1.0107123},   {0.19942053, 1.068824},
    {0.38605705, 1.1563928},    {-0.16756529, 0.9615808},  {0.32817602, 0.21989337},
    {0.41141313, 0.3578073},    {0.49127796, 1.1678538},   {0.27080515, 1.195178},
    {-0.19307071, 0.6481067},   {0.399859, 0.7892937},     {0.39875022, 0.80587196},
    {0.39717573, 0.8256797},    {0.3931817, 0.85224336},   {0.3670306, 0.9161113},
    {0.3256227, 0.7724022},     {0.31488904, 0.76426226},  {0.3001029, 0.7583232},
    {0.2565659, 0.73397243},    {0.0438394, 0.6234349},    {0.40628996, 0.30296788},
    {0.37707803, 0.19498621},   {0.34125936, 0.21069102},  {0.33733743, 0.7842425},
    {0.00882016, 0.769232},     {0.4335431, 0.1821002},    {0.33409703, 0.9826546},
    {0.49011812, 0.3896104},    {0.45311242, 0.34152514},  {0.4899982, 0.33611432},
    {0.369907, 0.43193236},     {0.49116373, 1.0932964},   {0.49107185, 1.0132186},
    {0.41421878, 1.008873},     {0.21551576, 0.8785059},   {0.27587482, 0.57461077},
    {0.2683325, 0.9399872},     {0.17091931, 0.56899554},  {0.23741819, 0.6283017},
    {0.12783033, 0.65916985},   {0.39875996, 1.0855893},   {0.33251646, 0.45881665},
    {0.16138549, 0.93153137},   {0.23269826, 0.99740875},  {0.17994387, 0.8051213},
    {-0.06026869, 0.7033027},   {0.10063827, 0.8241594},   {-0.15810522, 0.7679798},
    {0.2014156, 0.7000692},     {0.365875, 0.3839739},     {0.4115726, 0.5293855},
    {0.378973, 0.5476473},      {0.43235463, 0.49621448},  {0.3385827, 0.15134089},
    {0.27179635, 0.12940899},   {0.21341887, 0.12485553},  {0.15807948, 0.12881717},
    {0.10610204, 0.14814937},   {0.03133116, 0.236169},    {-0.21341309, 0.38895622},
    {0.07818349, 0.3101151},    {0.1318462, 0.32528982},   {0.19485526, 0.32642388},
    {0.25329807, 0.31256682},   {0.30569646, 0.29578218},  {0.34839994, 0.2842457},
    {-0.3824783, 0.41054142},   {0.37162504, 0.5664833},   {0.41687053, 0.40615496},
    {0.4433516, 0.5242282},     {0.44805393, 0.5562703},   {0.43453053, 0.5407472},
    {0.37351128, 0.58924097},   {0.46121803, 0.55474806},  {0.45942986, 0.5810936},
    {0.35955238, 0.24802393},   {0.38181108, 0.25985107},  {0.40143687, 0.26679716},
    {0.11717269, 0.2102652},    {0.0940459, 0.2016577},    {0.5217974, 0.39331725},
    {0.8625129, 0.23113514},    {0.5369363, 0.57397795},   {1.1896138, 0.00617525},
    {0.7275363, 0.28242856},    {0.7756985, 0.2884565},    {0.82466465, 0.28205347},
    {0.88921595, 0.24591576},   {0.6788919, 0.27210945},   {0.7640089, 0.166177},
    {0.7199609, 0.16991326},    {0.8099376, 0.17186326},   {0.8479136, 0.18300733},
    {0.9368992, 0.28424102},    {0.67367214, 1.0503516},   {0.8795338, 0.22195426},
    {1.1875838, 0.26458502},    {1.0039485, 0.24965489},   {0.74551606, 0.50375396},
    {0.54075617, 0.7095265},    {0.5365969, 0.76231945},   {0.59742403, 0.7215222},
    {0.6420548, 0.7379461},     {0.5787324, 0.7634331},    {0.617019, 0.766611},
    {0.71218634, 0.8469107},    {0.513503, 0.52683127},    {0.5170686, 0.49132976},
    {0.91894245, 0.11362247},   {0.66487545, 0.36299667},  {0.61502695, 0.52894545},
    {0.6296784, 0.50242335},    {0.88566196, 0.49919614},  {0.5193738, 0.4423927},
    {0.7780587, 0.05788935},    {0.8504331, 0.07610969},   {1.0753254, -0.1005309},
    {0.5824533, 0.09305263},    {0.6804744, 0.18382579},   {0.7485537, 0.79121745},
    {1.2577202, 0.8495136},     {0.59192824, 0.57196105},  {0.5665197, 0.59321034},
    {0.6999867, 0.7877651},     {0.6814933, 0.7868972},    {0.8846023, 0.03829005},
    {0.62761134, 0.5547819},    {0.6917209, 0.05532694},   {0.6966465, 0.01012804},
    {0.7876697, -0.2309872},    {0.9680314, -0.03263693},  {0.7294528, -0.1080169},
    {0.96877015, 0.08704082},   {1.0685298, 0.05000517},   {0.538806, 0.7375185},
    {0.5849781, 0.7415651},     {0.62764204, 0.7509944},   {0.58739805, 0.5847989},
    {0.68912315, 0.78645504},   {0.6626941, 0.8087924},    {0.6616096, 0.7864889},
    {0.5612171, 0.5442156},     {0.61282057, 0.7837617},   {0.575564, 0.7838267},
    {0.5344426, 0.7838985},     {0.551505, 0.93764293},    {0.5399973, 0.8616131},
    {0.53859717, 0.8290639},    {0.5384943, 0.8056173},    {0.53862303, 0.78905153},
    {0.6185288, 0.78891206},    {0.62114686, 0.8035485},   {0.62705064, 0.81825733},
    {0.635676, 0.8328036},      {0.6854969, 0.69067734},   {1.3517375, 0.54796624},
    {0.64465326, 0.78908265},   {0.6510032, 0.8004538},    {0.5471015, 0.62291807},
    {0.62742317, 0.59512955},   {0.55593795, 0.6091671},   {0.7161671, 0.39546603},
    {0.7836529, 0.435396},      {0.64694774, 0.5258542},   {0.94603044, -0.1820665},
    {0.86011904, -0.08652072},  {0.79549086, 0.01118712},  {0.66893554, 0.8840338},
    {0.59274685, 0.02056277},   {0.613851, -0.11025709},   {0.64526045, -0.25000137},
    {0.8639107, 0.26336375},    {0.9881146, 0.3277454},    {0.6445285, 0.26371115},
    {0.92017305, 0.18616839},   {0.61790556, 0.3323734},   {0.58225924, 0.5077285},
    {1.0597262, 0.36687428},    {0.93791103, 0.36642405},  {0.86892897, 0.38505408},
    {0.78624976, 0.37287512},   {0.7223912, 0.34902957},   {0.6687594, 0.32310694},
    {0.5315497, 0.2757726},     {1.0409807, 0.48452145},   {0.9700836, 0.17458573},
    {0.5065989, 0.55419755},    {0.6590531, 0.41624966},   {1.3414742, 0.26715896},
    {0.62023264, 0.30108824},   {0.67289865, 0.5290446},   {0.9036883, 0.22435239},
    {0.59769833, 0.47659585},   {1.3194624, 0.6974514},    {0.63339525, 0.24286939},
    {0.5571053, 0.45250946},    {0.9535533, 0.9380257},    {1.0260391, 1.0303764},
    {1.1858007, 0.51410204},    {1.0515786, 0.867869},     {1.1375865, 0.14722979},
    {0.6935665, 1.1218798},     {0.5063422, 0.58382744},   {0.69926125, 0.45745537},
    {1.0669235, 0.26074636},    {0.8110406, 0.25864118},   {0.7674977, 0.26644707},
    {0.67500204, 0.81528693},   {1.0435516, 0.5990178},    {0.6121316, 1.2306852},
    {0.81222653, 1.1483234},    {0.9056057, 1.0975065},    {0.7270778, 0.26337218},
    {0.6791554, 0.25763443},    {0.6487802, 0.24975733},   {1.0302606, 0.16233999},
    {0.68710136, 0.19869283},   {0.72731376, 0.18743533},  {0.7673578, 0.1862774},
    {0.81092334, 0.1914876},    {0.84171957, 0.1999683},   {1.2727026, 0.12110176},
    {0.8417947, 0.24301787},    {0.63978463, 0.6627527},   {0.5866921, 0.5600102},
    {0.5511283, 0.6567636},     {0.8655194, 1.009457},     {0.78306264, 1.0678959},
    {0.59620714, 1.1564037},    {1.149833, 0.9592815},     {0.65151644, 0.21932903},
    {0.56865776, 0.3571483},    {0.71228063, 1.1944076},   {1.1742088, 0.6457327},
    {0.5818109, 0.78897613},    {0.5829775, 0.80555046},   {0.5846211, 0.82535255},
    {0.5887078, 0.8519021},     {0.6150045, 0.916079},     {0.65597004, 0.771831},
    {0.66669285, 0.7636482},    {0.6814582, 0.7576576},    {0.7245435, 0.73241323},
    {0.9371713, 0.62184393},    {0.5736738, 0.30186948},   {0.60240346, 0.19448838},
    {0.6383993, 0.21017241},    {0.64431435, 0.7837067},   {0.9726586, 0.7675604},
    {0.54576766, 0.18157108},   {0.6477745, 0.98230904},   {0.5269076, 0.34123868},
    {0.61068684, 0.43131724},   {0.56792, 1.0087004},      {0.7662271, 0.8776794},
    {0.7048996, 0.57387614},    {0.7136024, 0.9394351},    {0.8097781, 0.56784695},
    {0.7435453, 0.62753886},    {0.85328954, 0.6578133},   {0.5835228, 1.0854707},
    {0.64810187, 0.45811343},   {0.82059515, 0.9304676},   {0.7494546, 0.9966611},
    {0.8015866, 0.80400985},    {1.0415541, 0.70138854},   {0.8809724, 0.8228132},
    {1.1396528, 0.7657218},     {0.7798614, 0.69881856},   {0.6143189, 0.383193},
    {0.56934875, 0.52867246},   {0.60162777, 0.54706186},  {0.5470082, 0.4963955},
    {0.6408297, 0.15073723},    {0.7075675, 0.12865019},   {0.76593757, 0.12391254},
    {0.8212976, 0.12768434},    {0.87334216, 0.14682971},  {0.948411, 0.23457018},
    {1.1936799, 0.38651106},    {0.90181875, 0.30865455},  {0.84818983, 0.3240165},
    {0.7851249, 0.32537246},    {0.72658616, 0.3116911},   {0.6740513, 0.2949461},
    {0.63111407, 0.28325075},   {1.362823, 0.4074953},     {0.60951644, 0.5658945},
    {0.5634702, 0.4055624},     {0.5374476, 0.5247268},    {0.53280455, 0.5561224},
    {0.5462737, 0.5405522},     {0.6075077, 0.58877414},   {0.51933056, 0.55477065},
    {0.52143395, 0.58103496},   {0.62030756, 0.24758299},  {0.59746987, 0.2574137},
    {0.5780933, 0.2652785},     {0.8624742, 0.2089644},    {0.8855709, 0.20027623}};

cv::Mat NORMALIZED_FACIAL_LANDMARKS(468, 1, CV_32FC2, _NORMALIZED_FACIAL_LANDMARKS_DATA);