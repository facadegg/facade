import onnx
import numpy as np
from typing import List, Tuple


def find_node_by_name(name: str, model: onnx.ModelProto):
    return [x for x in model.graph.node if x.name == name][0]


def find_initializer_by_name(name: str, model: onnx.ModelProto):
    return [x for x in model.graph.initializer if x.name == name][0]


if __name__ == "__main__":
    model = onnx.load('/Users/shukantpal/Downloads/Bryan_Greynolds.onnx')

    critical_shape = find_initializer_by_name('const_fold_opt__167', model)
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

    for i, mm in enumerate(matmuls):
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

        corres_add = adds[i]
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


    onnx.save(model, '/opt/facade/Bryan_Greynolds.onnx')
