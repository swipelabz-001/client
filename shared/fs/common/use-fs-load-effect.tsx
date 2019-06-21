// @flow
import * as React from 'react'
import * as Container from '../../util/container'
import * as Types from '../../constants/types/fs'
import * as Constants from '../../constants/fs'
import * as FsGen from '../../actions/fs-gen'

const useFsLoadEffect = ({
  path,
  refreshTag,
  wantChildren,
  wantPathMetadata,
}: {
  path: Types.Path
  refreshTag?: Types.RefreshTag
  wantChildren?: boolean
  wantPathMetadata?: boolean
}) => {
  const isPathItem = Types.getPathLevel(path) > 2 || Constants.hasSpecialFileElement(path)

  const dispatch = Container.useDispatch()
  const loadPathMetadata = React.useCallback(
    isPathItem ? refreshTag => dispatch(FsGen.createLoadPathMetadata({path, refreshTag})) : () => {},
    [dispatch, path, isPathItem]
  )
  const loadChildren = React.useCallback(
    isPathItem ? refreshTag => dispatch(FsGen.createFolderListLoad({path, refreshTag})) : () => {},
    [dispatch, path, isPathItem]
  )

  const online = Container.useSelector(state => state.fs.kbfsDaemonStatus.online)
  const load = React.useCallback(
    (refreshTag?: Types.RefreshTag) => {
      online && wantPathMetadata && loadPathMetadata(refreshTag)
      online && wantChildren && loadChildren(refreshTag)
    },
    [online, wantChildren, wantPathMetadata, loadPathMetadata, loadChildren]
  )

  React.useEffect(() => load(refreshTag), [load, refreshTag])
}

export default useFsLoadEffect
