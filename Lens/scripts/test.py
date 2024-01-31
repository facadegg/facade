import onnx
import numpy as np
from typing import List, Tuple


def find_node_by_name(name: str, model: onnx.ModelProto):
    return [x for x in model.graph.node if x.name == name][0]


def find_initializer_by_name(name: str, model: onnx.ModelProto):
    return [x for x in model.graph.initializer if x.name == name][0]


def delete_node_recursive(name: str, model: onnx.ModelProto):
    node = find_node_by_name(name, model)

    if len(node.output) > 0:
        output = node.output[0]

        for other_node in list(model.graph.node):
            if len(other_node.input) > 0 and output in list(other_node.input):
                delete_node_recursive(other_node.name, model)
                break

    model.graph.node.remove(node)


if __name__ == "__main__":
    model = onnx.load('/Users/shukantpal/Downloads/Zahar_Lupin.onnx')
    model.graph.input[0].type.tensor_type.shape.dim.pop(0)
    model.graph.input[0].type.tensor_type.shape.dim.insert(0, onnx.TensorShapeProto.Dimension(dim_value=1))
    for output in model.graph.output:
        output.type.tensor_type.shape.dim[0].CopyFrom(onnx.TensorShapeProto.Dimension(dim_value=1))

    reshape_109 = find_node_by_name('Reshape_109', model)
    critical_shape = find_initializer_by_name(reshape_109.input[1], model)
    critical_shape.CopyFrom(onnx.TensorProto(name=critical_shape.name,
                                             dims=[4],
                                             data_type=onnx.TensorProto.INT64,
                                             int64_data=[1, 1, 224, 112]))

    print(type(critical_shape))
    print(critical_shape)

    rm_node = find_node_by_name('Mean_1', model)
    rm_node.attribute[0].CopyFrom(onnx.AttributeProto(name=rm_node.attribute[0].name,
                                                      ints=[2,3],
                                                      type=onnx.AttributeProto.INTS))

    # mul_node = find_node_by_name('mul_1', model)
    # mul_node_index = list(model.graph.node).index(mul_node)
    # mul_output_original = mul_node.output[0]
    # mul_node.output[0] = 'mul_intermediate_0'
    #
    # print('HWERER')
    # print(mul_node.output[0])
    #
    # model.graph.initializer.append(onnx.TensorProto(name="adjust_1",
    #                                                 dims=[4],
    #                                                 data_type=onnx.TensorProto.INT64,
    #                                                 int64_data=[1, 1, 224, 112]))
    # adjust_node = onnx.NodeProto(input=['mul_intermediate_0', 'adjust_1'],
    #                              output=[mul_output_original],
    #                              op_type="Reshape",
    #                              name="adjust")
    # model.graph.node.append(adjust_node)

    print('---------------------------------------------------------------------------------------')
    print('---------------------------------------------------------------------------------------')
    print('---------------------------------------------------------------------------------------')

    matmuls = [
        find_node_by_name('MatMul_6', model),
        find_node_by_name('MatMul_4', model)
    ]
    adds = [find_node_by_name('Add_82', model), find_node_by_name('Add_80', model)]

    for line_idx, mm in enumerate(matmuls):
        mmi = list(model.graph.node).index(mm)
        model.graph.node.remove(mm)

        mm_weights = find_initializer_by_name(mm.input[1], model)
        mm_conv_equiv = onnx.NodeProto(name=mm.name.replace('MatMul', 'Conv_Equiv'),
                                       input=[mm.input[0], mm.input[1]],
                                       output=[mm.output[0]],
                                       op_type='Conv',
                                       attribute=[
                                           onnx.AttributeProto(name='auto_pad',
                                                               s='NOTSET'.encode('utf8'),
                                                               type=onnx.AttributeProto.STRING),
                                           onnx.AttributeProto(name='dilations',
                                                               ints=[1,1],
                                                               type=onnx.AttributeProto.INTS),
                                           onnx.AttributeProto(name='group',
                                                               i=1,
                                                               type=onnx.AttributeProto.INT),
                                           onnx.AttributeProto(name='kernel_shape',
                                                               ints=[224, 112],
                                                               type=onnx.AttributeProto.INTS),
                                           onnx.AttributeProto(name='pads',
                                                               ints=[0,0,0,0],
                                                               type=onnx.AttributeProto.INTS),
                                           onnx.AttributeProto(name='strides',
                                                               ints=[1,1],
                                                               type=onnx.AttributeProto.INTS)
                                       ])
        model.graph.node.insert(mmi, mm_conv_equiv)

        weights_data = mm_weights.raw_data
        weights_np = np.frombuffer(weights_data, dtype=np.float32)
        weights_np = weights_np.reshape((25088, 512))
        weights_np = weights_np.T
        weights_np = weights_np.reshape((512, 224, 112))
        mm_weights.raw_data = np.ndarray.tobytes(weights_np)
        mm_weights.dims[0] = 512
        mm_weights.dims[1] = 224
        mm_weights.dims.append(112)

        model.graph.initializer.append(onnx.TensorProto(name="adjust_shape_" + mm.name,
                                                        dims=[3],
                                                        data_type=onnx.TensorProto.INT64,
                                                        int64_data=[512, 1, 1]))
        adjust_node = onnx.NodeProto(name='adjust_' + mm.name,
                                     input=[mm.output[0], 'adjust_shape_' + mm.name],
                                     output=['intermediate_' + mm.name],
                                     op_type='Reshape')
        model.graph.node.append(adjust_node)

        corres_add = adds[line_idx]
        corres_add.input[0] = 'intermediate_' + mm.name
        add_weights = find_initializer_by_name(corres_add.input[1], model)
        add_weights.dims[0] = 512
        add_weights.dims[1] = 1
        add_weights.dims.append(1)



    print('---------------------------------------------------------------------------------------')
    print('---------------------------------------------------------------------------------------')
    print('---------------------------------------------------------------------------------------')


    nodes: List[Tuple[onnx.NodeProto, onnx.NodeProto]] = [
        (find_node_by_name('MatMul_7', model), find_node_by_name('Add_83', model)),
        (find_node_by_name('MatMul_5', model), find_node_by_name('Add_81', model)),
    ]
    for node in nodes:
        matmul = node[0]
        add = node[1]

        weights = find_initializer_by_name(matmul.input[1], model)
        weights.dims[1] = 224
        weights.dims.append(224)

        mmi = list(model.graph.node).index(matmul)
        model.graph.node.remove(matmul)
        model.graph.node.insert(mmi,
                                onnx.NodeProto(name=matmul.name.replace('MatMul', 'Mul_Equiv'),
                                               input=[matmul.input[0], matmul.input[1]],
                                               output=[matmul.output[0] + '_intermediate'],
                                               op_type='Mul'))
        model.graph.node.insert(mmi + 1,
                                onnx.NodeProto(name=matmul.name.replace('MatMul', 'Add_Equiv',),
                                               input=[matmul.output[0] + '_intermediate'],
                                               output=[matmul.output[0]],
                                               op_type='ReduceSum',
                                               attribute=[
                                                   onnx.AttributeProto(name='axes',
                                                                       ints=[0],
                                                                       type=onnx.AttributeProto.INTS),
                                                   onnx.AttributeProto(name='keepdims',
                                                                       i=0,
                                                                       type=onnx.AttributeProto.INT)
                                               ]))

        add_weights = find_initializer_by_name(add.input[1], model)
        add_weights.dims[0] = 224
        add_weights.dims[1] = 224

    print('---------------------------------------------------------------------------------------')
    print('---------------------------------------------------------------------------------------')
    print('---------------------------------------------------------------------------------------')

    square_node = find_node_by_name('Square_1', model)
    sni = list(model.graph.node).index(square_node)
    model.graph.node.remove(square_node)
    model.graph.initializer.append(onnx.TensorProto(name='equiv_pow_2',
                                                    dims=[1],
                                                    data_type=onnx.TensorProto.FLOAT,
                                                    float_data=[2]))
    model.graph.node.insert(sni,
                            onnx.NodeProto(name=square_node.name + '_Equiv',
                                           input=[square_node.input[0], 'equiv_pow_2'],
                                           output=[square_node.output[0]],
                                           op_type='Pow'
                                           ))

    print('---------------------------------------------------------------------------------------')
    print('---------------------------------------------------------------------------------------')
    print('---------------------------------------------------------------------------------------')

    nodes:  List[Tuple[onnx.NodeProto, onnx.NodeProto]] = [
        (find_node_by_name('Reshape_143', model), find_node_by_name('transpose_29', model)),
        (find_node_by_name('Reshape_146', model), find_node_by_name('transpose_30', model)),
        (find_node_by_name('Reshape_149', model), find_node_by_name('transpose_31', model)),
        (find_node_by_name('Reshape_152', model), find_node_by_name('transpose_32', model)),
        (find_node_by_name('Reshape_155', model), find_node_by_name('transpose_33', model)),

        (find_node_by_name('Reshape_117', model), find_node_by_name('transpose_24', model)),
        (find_node_by_name('Reshape_122', model), find_node_by_name('transpose_25', model)),
        (find_node_by_name('Reshape_127', model), find_node_by_name('transpose_26', model)),
        (find_node_by_name('Reshape_132', model), find_node_by_name('transpose_27', model)),
        (find_node_by_name('Reshape_140', model), find_node_by_name('transpose_28', model)),

        (find_node_by_name('Reshape_185', model), find_node_by_name('transpose_39', model)),
        (find_node_by_name('Reshape_188', model), find_node_by_name('transpose_40', model)),
        (find_node_by_name('Reshape_191', model), find_node_by_name('transpose_41', model)),
        (find_node_by_name('Reshape_194', model), find_node_by_name('transpose_42', model)),
        (find_node_by_name('Reshape_197', model), find_node_by_name('transpose_43', model))
    ]

    for reshape_node, transpose_node in nodes:
        shape_name = reshape_node.input[1]
        shape_weights = find_initializer_by_name(shape_name, model)

        if shape_weights.raw_data:
            shape = np.frombuffer(shape_weights.raw_data, dtype=np.int64)

            d1 = shape[1]
            d2 = shape[2]
            d3 = shape[3]
            d4 = shape[4]
            d5 = shape[5]
            shape_weights.CopyFrom(onnx.TensorProto(name=shape_weights.name,
                                                    dims=[4],
                                                    data_type=onnx.TensorProto.INT64,
                                                    int64_data=[d1, d2, d3 * d4, d5]))

        perm = transpose_node.attribute[0]
        perm.CopyFrom(onnx.AttributeProto(name=perm.name,
                                          ints=[2,0,3,1],
                                          type=onnx.AttributeProto.INTS))


    print('---------------------------------------------------------------------------------------')
    print('---------------------------------------------------------------------------------------')
    print('---------------------------------------------------------------------------------------')

    delete_node_recursive('Conv_Equiv_4', model)
    model.graph.output.pop(0)

    onnx.save(model, '/opt/facade/Zahar_Lupin.onnx')
