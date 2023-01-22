#!/bin/bash
shopt -s extglob

ROOT=$(git rev-parse --show-toplevel)
K8S_FOLDER="kubernetes/apps"
K8S_ROOT="$ROOT/$K8S_FOLDER"

for DIR in $K8S_ROOT/*/; do
    echo "Processing $DIR"

    ns=$(basename "$DIR")
    export NAMESPACE=$ns
    if [ ! -f "$DIR/namespace.yaml" ]; then

        echo "$DIR missing namespace, creating"

        ns=$(basename $DIR)
        export NAMESPACE=$ns

        envsubst <"$ROOT/templates/namespace/namespace.yaml" >"$DIR/namespace.yaml"

    fi

    envsubst <"$ROOT/templates/namespace/kustomization.yaml" >"$DIR/kustomization.yaml"

    for FILE in $DIR*.yaml; do

        if [ ! $(basename $FILE) == "kustomization.yaml" ] && [ ! $(basename $FILE) == "namespace.yaml" ]; then
            echo "  - ./$FILE" >>"$DIR/kustomization.yaml"
        fi

    done

    for APP in $DIR*/; do
        APP_NAME=$(basename $APP)
        echo " Adding $APP_NAME to $FILE"
        if [ -f "$APP/wip" ]; then

            echo "WARN:: $APP_NAME has a wip file, adding commented"
            echo "  # - ./$APP_NAME/ks.yaml # TODO: Disabled by WIP file" >>"$DIR/kustomization.yaml"

        else

            rm "$APP/ks.yaml"
            echo "  - ./$APP_NAME/ks.yaml" >>"$DIR/kustomization.yaml"

        fi

        # Check all yaml for correct namespace
        for FILE in $APP*.yaml; do

            if [[ $(yq '.metadata.namespace') != null ]]; then
                echo "Ensuring namespace is $NAMESPACE in $FILE"
                yq -i '.metadata.namespace=strenv(NAMESPACE)' "$FILE"

            fi

        done

        for SECTION in $APP*/; do
            SECTION_NAME=$(basename "$SECTION")

            export FULLDIR="./$K8S_FOLDER/$ns/$APP_NAME/$SECTION_NAME"
            export APP_NAME=$APP_NAME
            export SECTION_NAME=$SECTION_NAME

            echo "Adding $SECTION_NAME to $APP_NAME ks.yml"
            envsubst <"$ROOT/templates/ks/ks.yaml" >>"$APP/ks.yaml"

            #    if helmrelease present, add HR healthcheck and ensure values are aligned
            if [ -f "$SECTION/helmrelease.yaml" ]; then

                envsubst <"$ROOT/templates/ks/hr-add.yaml" >>"$APP/ks.yaml"
                yq -i '.metadata.namespace=strenv(NAMESPACE)' "$SECTION/helmrelease.yaml"
                yq -i '.metadata.name="cluster-app-"+strenv(APP_NAME)+"-"+strenv(SECTION_NAME)' "$SECTION/helmrelease.yaml"

            fi

            # Check all yaml for correct namespace
            for FILE in $SECTION*.yaml; do

                if [[ $(yq '.metadata.namespace') != null ]]; then
                    echo "sdfEnsuring namespace is $NAMESPACE in $FILE"
                    yq -i '.metadata.namespace=strenv(NAMESPACE)' "$FILE"

                fi

            done
        done

        # if [ ! -d "$dir/app" ]; then
        #   echo "creating app folder for $dir"
        #   mkdir "$dir/app"
        #   mv $dir/!(app) "$dir/app"
        #   appname=$(basename "$dir")
        #   ns=$(basename $(dirname "$dir"))
        #
        #   export FULLDIR="$dir"
        #   export APP_NAME=$appname
        #   export NAMESPACE=$ns
        #   envsubst < "$ROOT/templates/ks/ks.yaml" > "$dir/ks.yaml"
        #
        #
        # fi
    done

done
